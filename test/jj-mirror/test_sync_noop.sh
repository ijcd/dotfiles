#!/usr/bin/env bash
# test_sync_noop — re-sync with no changes is a no-op (prime commit ids unchanged).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
echo a1 > f && jj commit -m "a1" 2>/dev/null; jj bookmark set wip/a1 -r @- 2>/dev/null
echo a2 > f && jj commit -m "a2" 2>/dev/null; jj bookmark set wip/a2 -r @- 2>/dev/null

"$SCRIPT" sync

before1=$(jj log --no-graph -r "pr/a1" -T 'commit_id.short() ++ "\n"')
before2=$(jj log --no-graph -r "pr/a2" -T 'commit_id.short() ++ "\n"')

"$SCRIPT" sync   # second sync — should not change anything

after1=$(jj log --no-graph -r "pr/a1" -T 'commit_id.short() ++ "\n"')
after2=$(jj log --no-graph -r "pr/a2" -T 'commit_id.short() ++ "\n"')

assert_eq "$before1" "$after1" "pr/a1 commit id changed on no-op sync"
assert_eq "$before2" "$after2" "pr/a2 commit id changed on no-op sync"

cd / && rm -rf "$repo"
echo "ok: sync_noop"
