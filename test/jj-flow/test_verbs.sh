#!/usr/bin/env bash
# test_verbs — the porcelain routes each verb to the right underlying tool
# (via JJFLOW_DELEGATE_DRYRUN so no tool actually runs / no repo needed), `help`
# lists the surface, and unknown verbs error.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

run() { JJFLOW_DELEGATE_DRYRUN=1 "$SCRIPT" "$@"; }

assert_contains "$(run catchup -f)"       'would-run: jj-catch-up -f'   "catchup → jj-catch-up"
assert_contains "$(run mirror -n)"        'would-run: jj-mirror sync -n' "mirror → jj-mirror sync"
assert_contains "$(run push)"             'would-run: jj-mirror push'   "push → jj-mirror push"
assert_contains "$(run integrate status)" 'would-run: jj-integrate status' "integrate → jj-integrate"
assert_contains "$(run tug --all)"        'would-run: jj-tug --all'     "tug → jj-tug"
assert_contains "$(run cleanup foo)"      'would-run: jj-cleanup foo'   "cleanup → jj-cleanup"

# ship is the gated composition: catch-up THEN push.
ship=$(run ship 2>&1)
assert_contains "$ship" 'would-run: jj-catch-up'  "ship runs catch-up first"
assert_contains "$ship" 'would-run: jj-mirror push' "ship then pushes"

# help lists the verbs.
help=$("$SCRIPT" help)
for v in catchup mirror push integrate tug cleanup ship; do
  assert_contains "$help" "$v" "help mentions $v"
done

# unknown verb errors (exit 2).
if "$SCRIPT" bogus-verb >/dev/null 2>&1; then fail "unknown verb should exit non-zero"; fi

echo "ok: verbs"
