#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 3)"
c2="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 2p)"
jj bookmark create ijcd/feat -r "$c2" 2>/dev/null   # feat3 unmerged → must be parked

JJ_CLEANUP_WS_ROOT="$(dirname "$wsA")" "$SCRIPT" teardown feat --park todo/keep-feat3

exists todo/keep-feat3 || fail "park happened before wip delete"
exists wip/feat  && fail "wip/feat deleted"
exists ijcd/feat && fail "ijcd/feat deleted"
[[ ! -d "$wsA" ]] || fail "workspace dir removed"

# denylist refusal
rc=0; "$SCRIPT" teardown default >/dev/null 2>&1 || rc=$?
[[ "$rc" -ne 0 ]] || fail "must refuse default"

cd / && rm -rf "$repo" "$wsA"; echo "ok: teardown_order"
