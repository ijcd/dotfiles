#!/usr/bin/env bash
# test_status_drift — status flags a member that advanced without a catchup, and
# reads clean once caught up.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase; mkwip wip/a

"$SCRIPT" add wip/a >/dev/null 2>&1
out="$("$SCRIPT" status 2>&1)"
[[ "$out" == *"wip/a"* ]] || fail "status should list the member: $out"
[[ "$out" != *"drift"* ]] || fail "fresh add should not show drift: $out"

# advance wip/a WITHOUT catchup
jj new wip/a 2>/dev/null; echo more > more.txt && jj commit -m more 2>/dev/null; jj bookmark set wip/a -r @- 2>/dev/null

out="$("$SCRIPT" status 2>&1)"
[[ "$out" == *"drift"* && "$out" == *"advanced"* ]] || fail "status should flag drift after advance: $out"

"$SCRIPT" catchup >/dev/null 2>&1
out="$("$SCRIPT" status 2>&1)"
[[ "$out" != *"drift"* ]] || fail "status should be clean after catchup: $out"

cd / && rm -rf "$repo"; echo "ok: status_drift"
