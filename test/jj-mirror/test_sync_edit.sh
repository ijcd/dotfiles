#!/usr/bin/env bash
# test_sync_edit — amend a middle source commit; that prime commit rebuilds
# and downstream prime commits cascade-rebuild.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
# Separate files per commit — a shared file edited by every commit in the
# chain makes jj mark the downstream commit itself conflicted after an
# upstream edit (each full-file overwrite looks like a competing edit to the
# same content), which spuriously trips Task 9's conflict detection.
# Independent files keep this test isolated to cascade-rebuild mechanics.
echo a1 > f1 && jj commit -m "a1" 2>/dev/null; jj bookmark set wip/a1 -r @- 2>/dev/null
echo a2 > f2 && jj commit -m "a2" 2>/dev/null; jj bookmark set wip/a2 -r @- 2>/dev/null
echo a3 > f3 && jj commit -m "a3" 2>/dev/null; jj bookmark set wip/a3 -r @- 2>/dev/null

"$SCRIPT" sync
before1=$(jj log --no-graph -r "pr/a1" -T 'commit_id.short() ++ "\n"')
before3=$(jj log --no-graph -r "pr/a3" -T 'commit_id.short() ++ "\n"')

# Amend wip/a2's content
jj edit wip/a2 2>/dev/null
echo a2-CHANGED > f2 && jj describe -m "a2" 2>/dev/null
jj edit @- 2>/dev/null        # move off wip/a2 so we can sync

"$SCRIPT" sync

after1=$(jj log --no-graph -r "pr/a1" -T 'commit_id.short() ++ "\n"')
after3=$(jj log --no-graph -r "pr/a3" -T 'commit_id.short() ++ "\n"')

assert_eq "$before1" "$after1" "pr/a1 (upstream of edit) should NOT change"
[[ "$before3" != "$after3" ]] || fail "pr/a3 (downstream) should cascade-rebuild"

# pr/a2 should now contain the CHANGED content
diff=$(jj log --no-graph -r "pr/a2" -T '""' -p)
[[ "$diff" == *"a2-CHANGED"* ]] || fail "pr/a2 content did not update: $diff"

cd / && rm -rf "$repo"
echo "ok: sync_edit"
