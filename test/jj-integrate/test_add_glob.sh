#!/usr/bin/env bash
# test_add_glob — `add 'wip/*'` expands to every current wip/* local bookmark
# (and only those), i.e. "integrate all wip/*".
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase; mkwip wip/a; mkwip wip/b; mkwip other/x

"$SCRIPT" add 'wip/*' >/dev/null 2>&1

m="$(jj config get jj-integrate.members 2>/dev/null)"
[[ "$m" == *"wip/a"* && "$m" == *"wip/b"* ]] || fail "glob should add all wip/*: $m"
[[ "$m" != *"other/x"* ]] || fail "glob wip/* must not match other/x: $m"
has_parent local/integration wip/a || fail "wip/a should be a parent"
has_parent local/integration wip/b || fail "wip/b should be a parent"
assert_eq "2" "$(nparents local/integration)" "two members → two parents"

cd / && rm -rf "$repo"; echo "ok: add_glob"
