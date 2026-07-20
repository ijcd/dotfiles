#!/usr/bin/env bash
# test_catchup_advance — a member gets a new commit; catchup re-parents the
# integration onto its new tip (the whole point of storing members by name).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase; mkwip wip/a

"$SCRIPT" add wip/a >/dev/null 2>&1
before=$(cid "local/integration-")

# advance wip/a with a new commit
jj new wip/a 2>/dev/null; echo more > more.txt && jj commit -m more 2>/dev/null; jj bookmark set wip/a -r @- 2>/dev/null

"$SCRIPT" catchup >/dev/null 2>&1
after=$(cid "local/integration-")
[[ "$before" != "$after" ]] || fail "catchup should move the parent onto the advanced tip"
assert_eq "$(cid wip/a)" "$after" "parent should be the new wip/a tip"

cd / && rm -rf "$repo"; echo "ok: catchup_advance"
