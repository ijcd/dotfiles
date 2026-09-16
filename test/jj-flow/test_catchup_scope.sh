#!/usr/bin/env bash
# test_catchup_scope — the "targeted catch-up" regression. Two guarantees:
#
#  (1) off-base SIBLING wip (a peer's stream, off local/main-peer) is never rewritten
#      — it isn't a descendant of my base, so the -s lift never touches it.
#
#  (2) an off-base NON-OWNED branch whose conflict would otherwise trip the gate does
#      NOT roll back my clean catch-up (the all-or-nothing bug). A nested base
#      local/main-sub hangs off my base; its wip/sub-x conflicts with the new trunk.
#      By nearest-base ownership sub-x is NOT mine, so the scoped conflict gate ignores
#      it: MY base + MY wip still advance onto the new trunk (exit 0), instead of the
#      blanket gate seeing sub-x's conflict and rolling everything back.
#
# The blanket restack+gate (pre-fix) rolls the whole thing back on sub-x's conflict:
# catchup returns 3 and wip/mine-a never advances. This test asserts the CORRECT
# targeted behavior, so it is red until the owned-set restack lands.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 't0\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1

# my base + my clean wip (edits fa only)
jj new master >/dev/null 2>&1; echo m > pm; jj commit -m rm >/dev/null 2>&1; jj bookmark set local/main-me -r @- >/dev/null 2>&1
jj new local/main-me >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/mine-a -r @- >/dev/null 2>&1

# nested base off my base + a nested wip that edits f (will conflict with the new trunk)
jj new local/main-me >/dev/null 2>&1; echo s > ps; jj commit -m rs >/dev/null 2>&1; jj bookmark set local/main-sub -r @- >/dev/null 2>&1
jj new local/main-sub >/dev/null 2>&1; echo "sub-change" > f; jj commit -m subx >/dev/null 2>&1; jj bookmark set wip/sub-x -r @- >/dev/null 2>&1

# a peer base (sibling off trunk) + its wip — off-base sibling, must stay untouched
jj new master >/dev/null 2>&1; echo p > pp; jj commit -m rp >/dev/null 2>&1; jj bookmark set local/main-peer -r @- >/dev/null 2>&1
jj new local/main-peer >/dev/null 2>&1; echo c > fc; jj commit -m pc >/dev/null 2>&1; jj bookmark set wip/peer-1 -r @- >/dev/null 2>&1

# advance trunk, editing f divergently so rebasing wip/sub-x conflicts on f
jj new master >/dev/null 2>&1; echo "trunk-change" > f; jj commit -m M1 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj config set --repo jj-mirror.prime-root master >/dev/null 2>&1

peer_before=$(jj log --no-graph -r 'wip/peer-1' -T 'commit_id' 2>/dev/null)

# run catchup as the 'me' agent (force base via config so the test needn't add a workspace)
jj config set --repo jj-flow.base local/main-me >/dev/null 2>&1
JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" catchup -f >/dev/null 2>&1 \
  || fail "catchup was rolled back by an off-base branch's conflict (all-or-nothing)"

# my clean wip landed on the new trunk (its ancestors include the new master tip)
jj log --no-graph -r 'wip/mine-a & descendants(master)' -T '"x"' 2>/dev/null | grep -q x \
  || fail "my wip/mine-a was not advanced onto the new trunk"

# off-base sibling wip/peer-1 was never rewritten
peer_after=$(jj log --no-graph -r 'wip/peer-1' -T 'commit_id' 2>/dev/null)
assert_eq "$peer_before" "$peer_after" "off-base sibling wip/peer-1 was NOT rewritten"

cd / && rm -rf "$repo"
echo "ok: catchup_scope"
