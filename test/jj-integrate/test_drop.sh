#!/usr/bin/env bash
# test_drop — drop removes a member and it STAYS out across a later catchup
# (persistent, unlike a glob refresh that would re-add it).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase; mkwip wip/a; mkwip wip/b

"$SCRIPT" add wip/a wip/b >/dev/null 2>&1
"$SCRIPT" drop wip/a >/dev/null 2>&1

m="$(jj config get jj-integrate.members 2>/dev/null)"
[[ "$m" != *"wip/a"* ]] || fail "wip/a should be dropped from members: $m"
[[ "$m" == *"wip/b"* ]] || fail "wip/b should remain: $m"
if has_parent local/integration wip/a; then fail "wip/a should not be a parent after drop"; fi
has_parent local/integration wip/b || fail "wip/b should remain a parent"

"$SCRIPT" catchup >/dev/null 2>&1
if has_parent local/integration wip/a; then fail "wip/a should STAY dropped after catchup"; fi

cd / && rm -rf "$repo"; echo "ok: drop"
