#!/usr/bin/env bash
# test_sync_create — first sync builds prime chain from source chain.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# Source chain: wip/a1 -> wip/a2 -> wip/a3
echo a1 > f && jj commit -m "a1" 2>/dev/null; jj bookmark set wip/a1 -r @- 2>/dev/null
echo a2 > f && jj commit -m "a2" 2>/dev/null; jj bookmark set wip/a2 -r @- 2>/dev/null
echo a3 > f && jj commit -m "a3" 2>/dev/null; jj bookmark set wip/a3 -r @- 2>/dev/null

"$SCRIPT" sync

# Expect three pr/ bookmarks
for name in pr/a1 pr/a2 pr/a3; do
  jj log --no-graph -r "$name" -T '""' >/dev/null 2>&1 \
    || fail "$name bookmark not created"
done

# Prime chain should be a linear sequence off trunk.
# pr/a1's parent is trunk; pr/a2's parent is pr/a1; pr/a3's parent is pr/a2.
p1=$(jj log --no-graph -r "pr/a1-" -T 'commit_id.short() ++ "\n"')
p2=$(jj log --no-graph -r "pr/a2-" -T 'commit_id.short() ++ "\n"')
p3=$(jj log --no-graph -r "pr/a3-" -T 'commit_id.short() ++ "\n"')
c1=$(jj log --no-graph -r "pr/a1"  -T 'commit_id.short() ++ "\n"')
c2=$(jj log --no-graph -r "pr/a2"  -T 'commit_id.short() ++ "\n"')

trunk=$(jj log --no-graph -r "trunk()" -T 'commit_id.short() ++ "\n"')
assert_eq "$trunk" "$p1" "pr/a1 parent"
assert_eq "$c1"    "$p2" "pr/a2 parent"
assert_eq "$c2"    "$p3" "pr/a3 parent"

cd / && rm -rf "$repo"
echo "ok: sync_create"
