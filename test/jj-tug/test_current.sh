#!/usr/bin/env bash
# test_current — current-workspace tug (no args) advances the nearest bookmark to
# @-, exactly like the classic `jj tug` alias.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo a1 > f1 && jj commit -m a1 2>/dev/null; jj bookmark set foo -r @- 2>/dev/null  # foo at a1
echo a2 > f2 && jj commit -m a2 2>/dev/null                                          # @- = a2, foo behind

"$SCRIPT" >/dev/null 2>&1
assert_eq "$(cid '@-')" "$(cid foo)" "foo tugged up to @-"

cd / && rm -rf "$repo"; echo "ok: current"
