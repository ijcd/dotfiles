#!/usr/bin/env bash
# test_rollback — catch-up snapshots before rewriting, and a rebase that would
# conflict is ROLLED BACK (jj op restore) so the shared stack is left untouched —
# not rewritten-and-stuck. This is the fleet-safety guarantee.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'line1\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo lo > lo; jj commit -m lb >/dev/null 2>&1; jj bookmark set local/main -r @- >/dev/null 2>&1
jj new local/main >/dev/null 2>&1; printf 'line1-wip\n' > f; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/a -r @- >/dev/null 2>&1
jj config set --repo jj-flow.trunk master >/dev/null 2>&1
jj config set --repo jj-flow.base  local/main >/dev/null 2>&1

# advance trunk with a CONFLICTING change to the same line
jj new master >/dev/null 2>&1; printf 'line1-master\n' > f; jj commit -m M1 >/dev/null 2>&1
jj bookmark set --allow-backwards master -r @- >/dev/null 2>&1

LM0=$(cid local/main); WIP0=$(cid wip/a)

out=$(JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" 2>&1); rc=$?

# snapshot pass ran
assert_contains "$out" 'snapshot' "catch-up snapshots before rewriting"
# conflict → exit 3, rolled back
assert_eq 3 "$rc" "conflicting rebase exits 3 (STOPPED)"
assert_contains "$out" 'rolled back' "reports the rollback"
# nothing rewritten: local/main + wip/a still at their pre-catchup commits
assert_eq "$LM0" "$(cid local/main)" "local/main unchanged after rollback"
assert_eq "$WIP0" "$(cid wip/a)"     "wip/a unchanged after rollback"
# no conflict left lying around
[[ -z "$(jj log --no-graph -r 'conflicts()' -T '"x"' 2>/dev/null)" ]] || fail "a conflict was left behind after rollback"

cd / && rm -rf "$repo"
echo "ok: rollback"
