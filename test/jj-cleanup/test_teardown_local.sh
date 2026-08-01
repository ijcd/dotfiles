#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 1)"
jj bookmark create ijcd/feat -r "$(cid wip/feat)" 2>/dev/null

"$SCRIPT" __test_del_bookmarks feat
exists wip/feat  && fail "wip/feat deleted"
exists ijcd/feat && fail "ijcd/feat deleted"

"$SCRIPT" __test_forget_ws feat
jj workspace list --ignore-working-copy -T 'name ++ "\n"' | grep -q '^feat$' && fail "workspace forgotten"

cd / && rm -rf "$repo" "$wsA"; echo "ok: teardown_local"
