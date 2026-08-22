#!/usr/bin/env bash
# test_rebase — catch-up rebases the PRIVATE stack (base + wip/*) onto an advanced
# trunk, and leaves ijcd/* PR branches untouched (they base-strip onto trunk, so
# they're not descendants of base and fall outside the rebase).
set -uo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'trunk\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo lo > lo; jj commit -m lb >/dev/null 2>&1; jj bookmark set local/main -r @- >/dev/null 2>&1
jj new local/main >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/a -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo p > fp; jj commit -m pa >/dev/null 2>&1; jj bookmark set ijcd/a -r @- >/dev/null 2>&1  # PR branch on trunk
jj config set --repo jj-flow.trunk master >/dev/null 2>&1
jj config set --repo jj-flow.base  local/main >/dev/null 2>&1

# advance trunk: master M0 → M1
jj new master >/dev/null 2>&1; echo m1 > fm1; jj commit -m M1 >/dev/null 2>&1; jj bookmark set --allow-backwards master -r @- >/dev/null 2>&1
IJCD0=$(cid ijcd/a)

JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" >/dev/null 2>&1 || fail "catchup returned non-zero"

# private stack moved onto the new trunk
is_ancestor "$(cid master)" "$(cid local/main)" || fail "local/main not rebased onto new master"
is_ancestor "$(cid local/main)" "$(cid wip/a)"   || fail "wip/a no longer sits on local/main"
# ijcd/* untouched
assert_eq "$IJCD0" "$(cid ijcd/a)" "ijcd/a must not be touched by catch-up"

cd / && rm -rf "$repo"
echo "ok: rebase"
