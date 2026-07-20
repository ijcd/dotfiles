#!/usr/bin/env bash
# test_add — add a single branch: self-bootstraps the bookmark, parent is just
# that branch (base is NOT a redundant parent), and the member persists.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase; mkwip wip/a

"$SCRIPT" add wip/a >/dev/null 2>&1

exists local/integration || fail "add should self-bootstrap local/integration"
has_parent local/integration wip/a || fail "wip/a should be a parent"
assert_eq "1" "$(nparents local/integration)" "single member → exactly one parent"
if has_parent local/integration local/main; then fail "base local/main must NOT be a redundant parent"; fi
[[ "$(jj config get jj-integrate.members 2>/dev/null)" == *"wip/a"* ]] || fail "member not persisted to config"

cd / && rm -rf "$repo"; echo "ok: add"
