#!/usr/bin/env bash
# test_forward_only — a bookmark AHEAD of @- is never rewound (only at-or-behind
# bookmarks are candidates; forward-only).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo a1 > f1 && jj commit -m a1 2>/dev/null; jj bookmark set foo -r @- 2>/dev/null   # foo at a1
a1="$(cid foo)"
echo a2 > f2 && jj commit -m a2 2>/dev/null; jj bookmark set foo -r @- 2>/dev/null   # foo advanced to a2
jj new "$a1" 2>/dev/null                                                             # @- = a1; foo (a2) ahead
foo_before="$(cid foo)"

"$SCRIPT" >/dev/null 2>&1
assert_eq "$foo_before" "$(cid foo)" "foo ahead of @- must not move"

cd / && rm -rf "$repo"; echo "ok: forward_only"
