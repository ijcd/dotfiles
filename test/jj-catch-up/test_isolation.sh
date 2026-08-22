#!/usr/bin/env bash
# test_isolation — the core per-agent guarantee: catch-up run from agent alice's
# workspace advances ONLY local/main-alice + wip/alice-*, leaving agent bob's base
# and wip byte-identical. No shared local/main is moved.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'x\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo r > personal; jj commit -m recipe >/dev/null 2>&1; jj bookmark set local/main -r @- >/dev/null 2>&1
# alice's base + wip (a copy of the recipe on master, then a feature commit)
jj new master >/dev/null 2>&1; echo r > personal; jj commit -m recipe-a >/dev/null 2>&1; jj bookmark set local/main-alice -r @- >/dev/null 2>&1
jj new local/main-alice >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/alice-x -r @- >/dev/null 2>&1
# bob's base + wip
jj new master >/dev/null 2>&1; echo r > personal; jj commit -m recipe-b >/dev/null 2>&1; jj bookmark set local/main-bob -r @- >/dev/null 2>&1
jj new local/main-bob >/dev/null 2>&1; echo b > fb; jj commit -m b >/dev/null 2>&1; jj bookmark set wip/bob-x -r @- >/dev/null 2>&1
jj config set --repo jj-flow.trunk master >/dev/null 2>&1
# alice's workspace
alice_ws="$repo-alice"; jj workspace add --name alice "$alice_ws" >/dev/null 2>&1

# advance trunk
jj new master >/dev/null 2>&1; echo m1 > fm1; jj commit -m M1 >/dev/null 2>&1; jj bookmark set --allow-backwards master -r @- >/dev/null 2>&1

BOB_BASE0=$(cid local/main-bob); BOB_WIP0=$(cid wip/bob-x)

# catch-up FROM alice's workspace → FLOW_BASE derives to local/main-alice
( cd "$alice_ws" && jj config set --repo jj-flow.trunk master >/dev/null 2>&1
  JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" >/dev/null 2>&1 ) || fail "alice catch-up returned non-zero"

# alice advanced onto new master
is_ancestor "$(cid master)" "$(cid local/main-alice)" || fail "local/main-alice not caught up"
is_ancestor "$(cid local/main-alice)" "$(cid wip/alice-x)" || fail "wip/alice-x no longer on alice base"
# bob completely untouched
assert_eq "$BOB_BASE0" "$(cid local/main-bob)" "local/main-bob untouched by alice's catch-up"
assert_eq "$BOB_WIP0"  "$(cid wip/bob-x)"      "wip/bob-x untouched by alice's catch-up"

cd / && rm -rf "$repo" "$alice_ws"
echo "ok: isolation"
