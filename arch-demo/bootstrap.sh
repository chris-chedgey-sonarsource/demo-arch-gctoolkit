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
INSTANCE="cloud"
SQS_URL="http://localhost:9000"
while [ $# -gt 0 ]; do
  case "$1" in
    --org) ORG="$2"; shift 2 ;;
    --instance) INSTANCE="$2"; shift 2 ;;
    --sqs-url) SQS_URL="$2"; shift 2 ;;
    --dry-run) DRY_RUN="yes"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

usage() {
  cat >&2 <<USAGE
usage: $0 <your-name> [--instance cloud|sqs] [--org <organization>] [--dry-run]

  <your-name>    short name, used in the project name and key (e.g. alice)
  --instance     cloud (default) or sqs for a local SonarQube Server
  --org          SonarQube Cloud organization key - required for cloud only
  --sqs-url      SonarQube Server base URL (default http://localhost:9000)

  SONAR_TOKEN must hold a user token for whichever instance you target.
  Cloud: https://sonarcloud.io/account/security

  SonarQube Server needs Developer Edition or above - branch analysis and
  architecture are both edition-gated, and this demo depends on branches.
USAGE
  exit 2
}
case "$INSTANCE" in
  cloud)
    HOST="https://sonarcloud.io"
    # 5.1.x is the version that bootstraps correctly against SonarQube Cloud.
    PLUGIN="org.sonarsource.scanner.maven:sonar-maven-plugin:5.1.0.4751:sonar"
    SCANNER_ARGS=(-Dsonar.scanner.sonarcloudUrl="https://sonarcloud.io"
                  -Dsonar.scanner.apiBaseUrl="https://api.sonarcloud.io")
    ;;
  sqs)
    HOST="$SQS_URL"
    # 4.x uses sonar-scanner-api and talks to the server directly. 5.x bootstraps
    # via sonar-scanner-java-library, which defaults to a Cloud host and fails.
    PLUGIN="org.sonarsource.scanner.maven:sonar-maven-plugin:4.0.0.4121:sonar"
    SCANNER_ARGS=()
    ORG=""   # SonarQube Server has no organizations
    ;;
  *) echo "unknown --instance '$INSTANCE' (use cloud or sqs)" >&2; exit 2 ;;
esac

[ -n "$OWNER" ] || usage
# No default organization on purpose: a default would quietly create projects in
# someone else's organization.
[ "$INSTANCE" != "cloud" ] || [ -n "$ORG" ] || { echo "--org is required for cloud" >&2; usage; }
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

# One call that proves the token works and the target is reachable.
if [ "$INSTANCE" = "cloud" ]; then
  if ! curl -sSf -u "$SONAR_TOKEN:" \
       "$HOST/api/organizations/search?organizations=$ORG" | grep -q "\"key\":\"$ORG\""; then
    echo "    cannot see organization '$ORG' with this token" >&2
    echo "    check the key at $HOST and that the token is valid" >&2
    exit 2
  fi
  echo "    token + org ok"
else
  if ! curl -sSf -m 5 "$HOST/api/system/status" | grep -q '"status":"UP"'; then
    echo "    no SonarQube Server responding at $HOST" >&2; exit 2
  fi
  EDITION=$(curl -sS -u "$SONAR_TOKEN:" "$HOST/api/navigation/global" \
            | python3 -c "import json,sys;print(json.load(sys.stdin).get('edition','unknown'))")
  echo "    server up, edition: $EDITION"
  case "$EDITION" in
    community)
      echo "    Community Edition has no branch analysis, which this demo needs." >&2
      echo "    Use Developer Edition or above, or the cloud instance." >&2; exit 2 ;;
  esac
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Keys are only required to be unique, and SonarQube Server has no org prefix.
if [ "$INSTANCE" = "cloud" ]; then KEY="${ORG}_${OWNER}-gctoolkit-arch-demo"
else KEY="${OWNER}-gctoolkit-arch-demo"; fi
NAME="${OWNER}:arch-demo:gctoolkit"
BRANCHES=(demo-parser-integration-added demo-parser-integration-removed)

api() { curl -sS -u "$SONAR_TOKEN:" "$HOST/api/$1" "${@:2}"; }

echo "==> project $KEY  (\"$NAME\")"
[ -n "$DRY_RUN" ] && { echo "dry run: would create project, set tags, set branch regex, write model, scan main + ${BRANCHES[*]}"; exit 0; }

if [ "$INSTANCE" = "cloud" ]; then
  api projects/create -X POST --data-urlencode "name=$NAME" \
    --data-urlencode "project=$KEY" -d "organization=$ORG&visibility=private" >/dev/null || true
else
  api projects/create -X POST --data-urlencode "name=$NAME" \
    --data-urlencode "project=$KEY" >/dev/null || true
fi

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
if [ "$INSTANCE" = "cloud" ]; then
  SONARQUBE_CLI_TOKEN="$SONAR_TOKEN" SONARQUBE_CLI_ORG="$ORG" \
    sonar architecture intended set -p "$KEY" --file "$REPO_DIR/arch-demo/intended-architecture.json"
else
  # `sonar architecture` refuses a Server connection outright, so write through the
  # API. It wants the project UUID, not the key - passing the key fails quietly.
  UUID=$(api "projects/search?q=$KEY" \
         | python3 -c "
import json,sys
cs=[c for c in json.load(sys.stdin).get('components',[]) if c.get('key')==sys.argv[1]]
print(cs[0]['projectUuid'] if cs else '')" "$KEY")
  [ -n "$UUID" ] || { echo "could not resolve project UUID for $KEY" >&2; exit 1; }
  python3 -c "
import json,sys
m=json.load(open(sys.argv[1]))['models'][0]
json.dump({'projectId': sys.argv[2], 'model': m}, sys.stdout)" \
    "$REPO_DIR/arch-demo/intended-architecture.json" "$UUID" > /tmp/ia-payload.$$.json
  curl -sSf -u "$SONAR_TOKEN:" -H 'Content-Type: application/json' \
    --data @/tmp/ia-payload.$$.json "$HOST/api/v2/architecture/models" >/dev/null \
    && echo "    intended architecture written"
  rm -f /tmp/ia-payload.$$.json
fi

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
  ( cd "$REPO_DIR" && mvn -B package "$PLUGIN" \
      -DskipTests \
      -Dmaven.antrun.skip=true \
      -Dsonar.token="$SONAR_TOKEN" \
      -Dsonar.host.url="$HOST" \
      -Dsonar.organization="$ORG" \
      -Dsonar.projectKey="$KEY" \
      -Dsonar.projectName="$NAME" \
      ${SCANNER_ARGS[@]+"${SCANNER_ARGS[@]}"} \
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
"$REPO_DIR/arch-demo/verify.sh" "$KEY" "$HOST"
echo
echo "Architecture:  $HOST/project/architecture/current?id=$KEY"
