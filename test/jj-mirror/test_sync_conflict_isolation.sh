#!/usr/bin/env bash
# test_sync_conflict_isolation — option 1 (per-thread rollback). One clean thread
# and one whose diff conflicts onto the prime root. The clean thread must mirror;
# the conflicting thread must be rolled back (no prime bookmark), and sync must
# exit non-zero. Proves a conflict in one thread no longer aborts the rest.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"

# Local base carrying base.txt, bookmarked local/main (the source root).
echo X > base.txt && jj commit -m "local base" 2>/dev/null
jj bookmark set local/main -r @- 2>/dev/null

# Clean thread off local/main: adds a brand-new file — applies onto trunk cleanly.
jj new local/main 2>/dev/null
echo c > clean.txt && jj commit -m "clean" 2>/dev/null
jj bookmark set wip/clean -r @- 2>/dev/null

# Dirty thread off local/main: modifies base.txt, which exists ONLY in the local
# base. Cherry-picking that diff onto trunk() (no base.txt) is a modify/delete
# conflict.
jj new local/main 2>/dev/null
echo Y > base.txt && jj commit -m "dirty" 2>/dev/null
jj bookmark set wip/dirty -r @- 2>/dev/null

# Sync should partially succeed: pr/clean created, pr/dirty rolled back, exit != 0.
rc=0
"$SCRIPT" sync >/dev/null 2>&1 || rc=$?
[[ $rc -ne 0 ]] || fail "sync should exit non-zero when a thread conflicts (got $rc)"

# Clean thread mirrored despite the other's conflict.
jj log --no-graph -r "pr/clean" -T 'commit_id' >/dev/null 2>&1 \
  || fail "pr/clean missing — clean thread should mirror despite the conflict"

# Conflicting thread NOT mirrored (rolled back to its own savepoint).
if jj log --no-graph -r "pr/dirty" -T 'commit_id' >/dev/null 2>&1; then
  fail "pr/dirty exists — the conflicting thread should have been rolled back"
fi

cd / && rm -rf "$repo"
echo "ok: sync_conflict_isolation"
