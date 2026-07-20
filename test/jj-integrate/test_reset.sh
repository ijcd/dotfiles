#!/usr/bin/env bash
# test_reset — reset sets the member set to every bookmark matching the `all`
# glob (default wip/*) and catches up.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase; mkwip wip/a; mkwip wip/b; mkwip other/x

"$SCRIPT" clear >/dev/null 2>&1     # start from empty
"$SCRIPT" reset >/dev/null 2>&1     # → all wip/*

m="$(jj config get jj-integrate.members 2>/dev/null)"
[[ "$m" == *"wip/a"* && "$m" == *"wip/b"* ]] || fail "reset should add all wip/*: $m"
[[ "$m" != *"other/x"* ]] || fail "reset (wip/*) must not include other/x: $m"
assert_eq "2" "$(nparents local/integration)" "reset → two wip/* parents"

cd / && rm -rf "$repo"; echo "ok: reset"
