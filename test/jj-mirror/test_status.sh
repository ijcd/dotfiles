#!/usr/bin/env bash
# test_status — status reports ok/stale/missing per pair.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

echo a1 > f && jj commit -m "a1"; jj bookmark set wip/a1 -r @-
echo a2 > f && jj commit -m "a2"; jj bookmark set wip/a2 -r @-
"$SCRIPT" sync

out="$("$SCRIPT" status)"
[[ "$out" == *"wip/a1"*"pr/a1"*"ok"*   ]] || fail "expected wip/a1 -> pr/a1 ok in status: $out"
[[ "$out" == *"wip/a2"*"pr/a2"*"ok"*   ]] || fail "expected wip/a2 -> pr/a2 ok in status: $out"

# Edit wip/a2 without syncing
jj edit wip/a2 && echo x > f && jj describe -m "a2"
jj edit @-

out="$("$SCRIPT" status)"
[[ "$out" == *"wip/a2"*"stale"* ]] || fail "expected wip/a2 stale: $out"

# Delete pr/a1 bookmark to simulate missing
jj bookmark delete pr/a1
out="$("$SCRIPT" status)"
[[ "$out" == *"wip/a1"*"missing"* ]] || fail "expected wip/a1 missing: $out"

cd / && rm -rf "$repo"
echo "ok: status"
