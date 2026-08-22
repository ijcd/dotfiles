#!/usr/bin/env bash
# test_guide — `jj-flow guide` emits the recipe doc (parseable structure), works
# OUTSIDE a jj repo (agents read it before cd-ing in), the single-verb filter
# narrows it, and `help` points to it.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# works outside a jj repo (run from /tmp, which is not a jj repo)
out=$( cd /tmp && "$SCRIPT" guide 2>&1 )
assert_contains "$out" '## MODEL'   "guide has a MODEL section"
assert_contains "$out" '## VERBS'   "guide has a VERBS section"
assert_contains "$out" '## RECIPE 2 — onboard on your own base' "guide has the onboard recipe"
# every recipe carries the parseable field set
for field in 'WHEN' 'DO' 'VERIFY' 'WHY'; do
  assert_contains "$out" "$field" "recipe field $field present"
done
assert_contains "$out" 'base fork' "guide shows the base fork command"
assert_contains "$out" '## NEVER'  "guide has a NEVER section"

# single-verb filter narrows to recipes mentioning that verb
out=$( cd /tmp && "$SCRIPT" guide catchup 2>&1 )
assert_contains "$out" 'catchup' "filtered guide mentions catchup"
[[ "$out" != *'RECIPE 8 — retire a merged PR'* ]] || fail "verb filter should exclude unrelated recipes"

# help points to the guide
assert_contains "$("$SCRIPT" help 2>&1)" 'jj-flow guide' "help points agents to the guide"

echo "ok: guide"
