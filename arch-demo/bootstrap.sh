#!/usr/bin/env bash
#
# Set up your own SonarQube Cloud project for the architecture demo.
#
#   ./arch-demo/bootstrap.sh <your-name> [--org <organization>] [--dry-run]
#
# Needs: SONAR_TOKEN (a SonarQube Cloud user token), Java 17+, Maven, git.
#        The SonarQube CLI (`sonar`) is optional; without it the model is
#        written through the public API instead.
#
set -euo pipefail

OWNER="${1:-}"; shift || true
ORG=""
DRY_RUN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --org) ORG="$2"; shift 2 ;;
    --dry-run) DRY_RUN="yes"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

usage() {
  cat >&2 <<USAGE
usage: $0 <your-name> --org <organization> [--dry-run]

  <your-name>   short name, used in the project name and key (e.g. alice)
  --org         your SonarQube Cloud organization key

  SONAR_TOKEN must hold a SonarQube Cloud user token:
  https://sonarcloud.io/account/security
USAGE
  exit 2
}
[ -n "$OWNER" ] || usage
# No default organization on purpose: a default would quietly create projects in
# someone else's organization.
[ -n "$ORG" ] || { echo "--org is required" >&2; usage; }
[ -n "${SONAR_TOKEN:-}" ] || { echo "SONAR_TOKEN is not set" >&2; usage; }

# Fail in seconds rather than minutes deep inside Maven.
echo "==> checking prerequisites"
missing=0
for c in git mvn java sonar; do
  if command -v "$c" >/dev/null 2>&1; then
    printf '    %-6s ok\n' "$c"
  else
    printf '    %-6s MISSING\n' "$c"; missing=1
  fi
done
if [ "$missing" = 1 ]; then
  cat >&2 <<'NEED'

  git, Maven and a JDK 17+ are needed to build and scan.
  The SonarQube CLI writes the intended architecture:
      brew install sonarsource/tap/sonarqube-cli
  Without it the scan runs with no architecture defined and every branch
  reports zero deviations, which looks like the demo working.
NEED
  exit 2
fi

# One call that proves the token works and the organization is reachable.
if ! curl -sSf -u "$SONAR_TOKEN:" \
     "https://sonarcloud.io/api/organizations/search?organizations=$ORG" \
     | grep -q "\"key\":\"$ORG\""; then
  echo "    cannot see organization '$ORG' with this token" >&2
  echo "    check the key at https://sonarcloud.io and that the token is valid" >&2
  exit 2
fi
echo "    token + org ok"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="${ORG}_${OWNER}-gctoolkit-arch-demo"
NAME="${OWNER}:arch-demo:gctoolkit"
HOST="https://sonarcloud.io"
BRANCHES=(demo-parser-integration-added demo-parser-integration-removed)

api() { curl -sS -u "$SONAR_TOKEN:" "$HOST/api/$1" "${@:2}"; }

echo "==> project $KEY  (\"$NAME\")"
[ -n "$DRY_RUN" ] && { echo "dry run: would create project, set tags, set branch regex, write model, scan main + ${BRANCHES[*]}"; exit 0; }

api projects/create -X POST \
  --data-urlencode "name=$NAME" --data-urlencode "project=$KEY" \
  -d "organization=$ORG&visibility=private" >/dev/null || true

api project_tags/set -X POST -d "project=$KEY&tags=${OWNER},arch-demo" >/dev/null

# MUST happen before any branch is scanned. A branch that does not match this
# pattern is analysed as short-lived: it reports only new code, which means
# architecture deviations silently do not appear and the demo looks clean when
# it is measuring nothing. Branches created before this is set must be deleted
# and rescanned to be reclassified.
echo "==> long-lived branch pattern"
api settings/set -X POST \
  --data-urlencode "key=sonar.branch.longLivedBranches.regex" \
  --data-urlencode "value=(main|master|demo-.*)" \
  -d "component=$KEY" >/dev/null

echo "==> intended architecture"
SONARQUBE_CLI_TOKEN="$SONAR_TOKEN" SONARQUBE_CLI_ORG="$ORG" \
  sonar architecture intended set -p "$KEY" --file "$REPO_DIR/arch-demo/intended-architecture.json"

scan() { # $1 = git ref, $2 = optional sonar branch name
  echo "==> scanning $1"
  git -C "$REPO_DIR" checkout -q "$1"
  # Guarded expansion: bash 3.2 (macOS) treats "${arr[@]}" on an empty array as
  # unbound under `set -u`, so main (no branch argument) would abort the run.
  local extra=()
  [ -n "${2:-}" ] && extra=(-Dsonar.branch.name="$2")
  # maven.antrun.skip stops the gclogs module downloading 362MB of GC test logs
  # in process-test-resources. It is test data only, nothing depends on the module,
  # and we skip tests anyway - but on a fresh clone it otherwise dominates the run.
  # The plugin version is pinned deliberately: 5.1.x is the one that works against
  # SonarQube Cloud. Older 3.x/4.x bootstrap against different hosts.
  ( cd "$REPO_DIR" && mvn -B package \
      org.sonarsource.scanner.maven:sonar-maven-plugin:5.1.0.4751:sonar \
      -DskipTests \
      -Dmaven.antrun.skip=true \
      -Dsonar.token="$SONAR_TOKEN" \
      -Dsonar.host.url="$HOST" \
      -Dsonar.organization="$ORG" \
      -Dsonar.projectKey="$KEY" \
      -Dsonar.projectName="$NAME" \
      -Dsonar.scanner.sonarcloudUrl="$HOST" \
      -Dsonar.scanner.apiBaseUrl="https://api.sonarcloud.io" \
      ${extra[@]+"${extra[@]}"} )
}

scan main

# Scanning without sonar.branch.name lands on the project's default branch, which
# SonarQube Cloud names "master" regardless of what git calls it. Rename it so the
# UI matches the repository - otherwise the branch selector reads master/demo-*
# and nothing corresponds to main.
echo "==> renaming the main branch to match git"
api project_branches/rename -X POST --data-urlencode "name=main" -d "project=$KEY" >/dev/null

for b in "${BRANCHES[@]}"; do scan "$b" "$b"; done
git -C "$REPO_DIR" checkout -q main

echo
echo "==> verifying"
"$REPO_DIR/arch-demo/verify.sh" "$KEY"
echo
echo "Architecture:  $HOST/project/architecture/current?id=$KEY"
