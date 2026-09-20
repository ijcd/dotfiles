#!/usr/bin/env bash
# test_stacked — catch-up preserves INTRA-THREAD STACKING. A stacked pair
# (wip/<child> on wip/<parent>, backing a PR whose base is the parent's PR) must come
# out of a catch-up still stacked: catchup runs `jj rebase -b $w -d $FLOW_BASE` once
# per owned wip, and if -b flattened the chain every catch-up would silently unstack
# the PRs — jj-vine would then reset every base to master on the next push.
# -b X -d BASE is `-s roots(BASE..X)`: only the chain ROOT is re-parented.
# NOTE the bookmark lister is alphabetical, so the loop hits wip/alice-child BEFORE
# wip/alice-parent — the adversarial order, where the child is rebased first.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'x\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
# alice's per-agent base (a copy of the recipe on master)
jj new master >/dev/null 2>&1; echo r > personal; jj commit -m recipe-a >/dev/null 2>&1
jj bookmark set local/main-alice -r @- >/dev/null 2>&1
# the stack: parent, then child ON the parent
jj new local/main-alice >/dev/null 2>&1; echo p > fp; jj commit -m parent >/dev/null 2>&1
jj bookmark set wip/alice-parent -r @- >/dev/null 2>&1
jj new wip/alice-parent >/dev/null 2>&1; echo c > fc; jj commit -m child >/dev/null 2>&1
jj bookmark set wip/alice-child -r @- >/dev/null 2>&1
jj config set --repo jj-flow.trunk master >/dev/null 2>&1
alice_ws="$repo-alice"; jj workspace add --name alice "$alice_ws" >/dev/null 2>&1

# advance trunk so the catch-up has real work to do
jj new master >/dev/null 2>&1; echo m1 > fm1; jj commit -m M1 >/dev/null 2>&1
jj bookmark set --allow-backwards master -r @- >/dev/null 2>&1

( cd "$alice_ws" && jj config set --repo jj-flow.trunk master >/dev/null 2>&1
  JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" >/dev/null 2>&1 ) || fail "catch-up returned non-zero"

# the stream advanced...
is_ancestor "$(cid master)" "$(cid local/main-alice)" || fail "local/main-alice not caught up"
is_ancestor "$(cid local/main-alice)" "$(cid wip/alice-parent)" || fail "parent left its base"
# ...and the stack SURVIVED: child still rides the parent, not the base.
is_ancestor "$(cid wip/alice-parent)" "$(cid wip/alice-child)" \
  || fail "catch-up FLATTENED the stack — wip/alice-child no longer descends wip/alice-parent"
# belt-and-braces: a flattened chain would make the child a DIRECT child of the base.
if jj log --no-graph -r 'wip/alice-child & children(local/main-alice)' -T '"y"' 2>/dev/null | grep -q y; then
  fail "catch-up re-parented wip/alice-child straight onto the base (unstacked)"
fi

cd / && rm -rf "$repo" "$alice_ws"
echo "ok: stacked"
