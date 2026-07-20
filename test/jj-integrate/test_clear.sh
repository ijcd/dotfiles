#!/usr/bin/env bash
# test_clear — clear empties the set and seats the bookmark as a bare single-
# parent commit on base.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase; mkwip wip/a

"$SCRIPT" add wip/a >/dev/null 2>&1
"$SCRIPT" clear >/dev/null 2>&1

assert_eq "1" "$(nparents local/integration)" "clear → single parent"
assert_eq "$(cid local/main)" "$(cid 'local/integration-')" "clear seats integration on base"
m="$(jj config get jj-integrate.members 2>/dev/null || echo '')"
[[ -z "$m" ]] || fail "clear should empty the member set: $m"

cd / && rm -rf "$repo"; echo "ok: clear"
