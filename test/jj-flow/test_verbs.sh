#!/usr/bin/env bash
# test_verbs — the porcelain routes each verb to the right underlying tool
# (via JJFLOW_DELEGATE_DRYRUN so no tool actually runs / no repo needed), `help`
# lists the surface, and unknown verbs error.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

run() { JJFLOW_DELEGATE_DRYRUN=1 "$SCRIPT" "$@"; }

# In-process modules (no delegated binary) — prove routing via their help text.
assert_contains "$("$SCRIPT" mirror --help 2>&1)"    'Re-derive the prime chain'          "mirror → mirror_main sync"
assert_contains "$("$SCRIPT" push --help 2>&1)"      'jj-vine'                             "push → mirror_main push"
assert_contains "$("$SCRIPT" tug --help 2>&1)"       'advance the nearest bookmark'       "tug → tug_main"
assert_contains "$("$SCRIPT" cleanup --help 2>&1)"   'clean up after a merged/closed PR'  "cleanup → cleanup_main"
assert_contains "$("$SCRIPT" integrate --help 2>&1)" 'octopus-merge bookmark'             "integrate → integrate_main"
assert_contains "$("$SCRIPT" catchup --help 2>&1)"   'rebase the private stack'           "catchup → catchup_main"

# ship is the gated composition: catch-up THEN push, in-process. Outside a jj repo
# catch-up fails first, so ship stops BEFORE any push (the gate).
rc=0; ship=$(cd /tmp && "$SCRIPT" ship 2>&1) || rc=$?
[[ "$rc" -ne 0 ]] || fail "ship should fail when catch-up can't run"
assert_contains "$ship" 'catching the private stack' "ship runs catch-up first"
[[ "$ship" != *'pushing PRs'* ]] || fail "ship must NOT push when catch-up fails (gate)"

# help lists the verbs.
help=$("$SCRIPT" help)
for v in catchup mirror push integrate tug cleanup ship; do
  assert_contains "$help" "$v" "help mentions $v"
done

# unknown verb errors (exit 2).
if "$SCRIPT" bogus-verb >/dev/null 2>&1; then fail "unknown verb should exit non-zero"; fi

echo "ok: verbs"
