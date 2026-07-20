#!/usr/bin/env bash
# test_topology — the mirror re-derives after a source topology change: abandon a
# middle commit, re-sync, and the prime stack reshapes (orphan cull + reparent).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

# stack wip/a1 < wip/a2 < wip/a3 (independent files, so the rebase is clean)
echo 1 > f1 && jj commit -m a1 2>/dev/null; jj bookmark set wip/a1 -r @- 2>/dev/null
echo 2 > f2 && jj commit -m a2 2>/dev/null; jj bookmark set wip/a2 -r @- 2>/dev/null
echo 3 > f3 && jj commit -m a3 2>/dev/null; jj bookmark set wip/a3 -r @- 2>/dev/null
"$SCRIPT" sync
for b in pr/a1 pr/a2 pr/a3; do jj log --no-graph -r "$b" -T '""' >/dev/null 2>&1 || fail "$b missing pre-change"; done

# Topology change: drop the MIDDLE bookmark + commit. Delete the bookmark first so
# jj doesn't slide it onto a1 (which would make a1 carry two source bookmarks).
a2=$(jj log --no-graph -r "wip/a2" -T 'commit_id.short()' | head -n1)
jj bookmark delete wip/a2 >/dev/null 2>&1
jj abandon "$a2" >/dev/null 2>&1        # rebases a3 onto a1
jj new 'trunk()' >/dev/null 2>&1        # park the working copy

"$SCRIPT" sync

# pr/a2 orphan-culled (source gone); pr/a1 + pr/a3 survive; pr/a3 reparents onto pr/a1.
if jj log --no-graph -r "pr/a2" -T '""' >/dev/null 2>&1; then fail "pr/a2 should be orphan-culled after wip/a2 abandon"; fi
for b in pr/a1 pr/a3; do jj log --no-graph -r "$b" -T '""' >/dev/null 2>&1 || fail "$b missing after topology change"; done
pa3=$(jj log --no-graph -r "pr/a3-" -T 'commit_id.short()' | head -n1)
ca1=$(jj log --no-graph -r "pr/a1" -T 'commit_id.short()' | head -n1)
assert_eq "$ca1" "$pa3" "pr/a3 should reparent onto pr/a1 after the middle abandon"

cd / && rm -rf "$repo"; echo "ok: topology"
