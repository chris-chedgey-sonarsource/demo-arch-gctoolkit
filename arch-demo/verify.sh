#!/usr/bin/env bash
#
# Check a bootstrapped demo project is actually measuring something.
#
#   ./arch-demo/verify.sh <project-key>
#
# Exists because the failure mode is silent: a branch that was analysed as
# short-lived reports no issues at all, so a broken demo shows zero deviations
# and looks like a pass.
#
set -euo pipefail
KEY="${1:-}"
[ -n "$KEY" ] || { echo "usage: $0 <project-key>" >&2; exit 2; }
[ -n "${SONAR_TOKEN:-}" ] || { echo "SONAR_TOKEN is not set" >&2; exit 2; }
HOST="https://sonarcloud.io"
ARCH_RULES="javaarchitecture:S7788,javaarchitecture:S7789,javaarchitecture:S8464,javaarchitecture:S8487"

# branch -> expected architecture deviations
EXPECT_main=0
EXPECT_added=1
EXPECT_removed=0

enc() { python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$1"; }
count() { # $1 = branch, $2 = optional rules filter
  local q="componentKeys=$KEY&branch=$(enc "$1")&ps=1"
  [ -n "${2:-}" ] && q="$q&rules=$2"
  curl -sS -u "$SONAR_TOKEN:" "$HOST/api/issues/search?$q" \
    | python3 -c "import json,sys;print(json.load(sys.stdin).get('total','?'))"
}

echo "branch                            type   all  arch  expected"
fail=0
types=$(curl -sS -u "$SONAR_TOKEN:" "$HOST/api/project_branches/list?project=$KEY")
for spec in "main:$EXPECT_main" \
            "demo-parser-integration-added:$EXPECT_added" \
            "demo-parser-integration-removed:$EXPECT_removed"; do
  b="${spec%:*}"; want="${spec##*:}"
  t=$(printf '%s' "$types" | python3 -c "
import json,sys
bs=json.load(sys.stdin).get('branches',[])
print(next((x.get('type','?') for x in bs if x['name']==sys.argv[1]), 'MISSING'))" "$b")
  all=$(count "$b"); arch=$(count "$b" "$ARCH_RULES")
  printf '%-33s %-6s %4s  %4s  %8s' "$b" "$t" "$all" "$arch" "$want"
  if [ "$t" = "SHORT" ]; then
    echo "   FAIL: short-lived, reports new code only"; fail=1
  elif [ "$t" = "MISSING" ]; then
    echo "   FAIL: not analysed"; fail=1
  elif [ "$all" = "0" ]; then
    echo "   FAIL: no issues at all - nothing was measured"; fail=1
  elif [ "$arch" != "$want" ]; then
    echo "   FAIL"; fail=1
  else
    echo "   ok"
  fi
done
[ "$fail" = 0 ] && echo && echo "All good - the demo will behave as scripted." || {
  echo; echo "Fix: check sonar.branch.longLivedBranches.regex covers (main|master|demo-.*),"
  echo "then delete the affected branches and rescan - type is set at analysis time."; exit 1; }
