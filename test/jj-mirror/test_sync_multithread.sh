#!/usr/bin/env bash
# test_sync_multithread — two independent source threads off trunk sync without
# cross-contamination. This is the scenario the Task 8 orphan-cull-in-sync_main
# restructure was built for: a per-thread `wanted` set with a repo-wide scan
# would delete the OTHER thread's prime bookmark on the second thread's pass.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# Thread A: single source bookmark off trunk.
echo a1 > fa && jj commit -m "a1" >/dev/null 2>&1
jj bookmark set wip/a1 -r @- >/dev/null 2>&1

# Thread B: single source bookmark on a parallel branch off trunk.
jj new 'trunk()' -m "b1" >/dev/null 2>&1
echo b1 > fb && jj describe -m "b1" >/dev/null 2>&1
jj bookmark set wip/b1 -r @ >/dev/null 2>&1

"$SCRIPT" sync

# Both prime bookmarks must survive — the cull ran once across both threads'
# `wanted` sets, so pr/a1 and pr/b1 are each in the union and neither is orphaned.
jj log --no-graph -r "pr/a1" -T '""' >/dev/null 2>&1 \
  || fail "pr/a1 orphaned by second thread's cull pass (multi-thread regression)"
jj log --no-graph -r "pr/b1" -T '""' >/dev/null 2>&1 \
  || fail "pr/b1 not created for thread b"

# Idempotence across threads: second sync leaves both untouched.
before_a=$(jj log --no-graph -r "pr/a1" -T 'commit_id.short() ++ "\n"')
before_b=$(jj log --no-graph -r "pr/b1" -T 'commit_id.short() ++ "\n"')
"$SCRIPT" sync
after_a=$(jj log --no-graph -r "pr/a1" -T 'commit_id.short() ++ "\n"')
after_b=$(jj log --no-graph -r "pr/b1" -T 'commit_id.short() ++ "\n"')
assert_eq "$before_a" "$after_a" "pr/a1 re-sync should be no-op"
assert_eq "$before_b" "$after_b" "pr/b1 re-sync should be no-op"

# Cross-thread orphan cull: delete one thread's source bookmark, sync.
# The other thread's prime bookmark MUST survive. This is the exact regression
# the sync_main-scoped `wanted` union guards against — a per-thread cull would
# delete pr/b1 while processing thread a (or vice-versa).
jj bookmark delete wip/a1 >/dev/null 2>&1
"$SCRIPT" sync

if jj log --no-graph -r "pr/a1" -T '""' >/dev/null 2>&1; then
  fail "pr/a1 should have been orphan-culled after wip/a1 deletion"
fi
jj log --no-graph -r "pr/b1" -T '""' >/dev/null 2>&1 \
  || fail "pr/b1 was clobbered by pr/a1's orphan cull (cross-thread contamination)"

cd / && rm -rf "$repo"
echo "ok: sync_multithread"
