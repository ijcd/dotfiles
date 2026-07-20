#!/usr/bin/env bash
# test_squash_conflict — a --squash thread whose cumulative diff conflicts on the
# prime root rolls back to its own per-thread savepoint; clean threads still sync;
# sync exits non-zero and the conflicting squash dest is NOT created.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo X > base.txt && jj commit -m "local base" 2>/dev/null; jj bookmark set local/main -r @- 2>/dev/null
# clean thread: adds a new file — squashes cleanly onto trunk().
jj new local/main 2>/dev/null; echo c > clean.txt && jj commit -m clean 2>/dev/null; jj bookmark set wip/clean -r @- 2>/dev/null
# dirty thread: MODIFIES base.txt, which exists only in the local/main base — the
# cumulative diff can't apply on trunk() (modify/delete conflict).
jj new local/main 2>/dev/null; echo Y > base.txt && jj commit -m dirty 2>/dev/null; jj bookmark set wip/dirty -r @- 2>/dev/null

"$SCRIPT" add 'wip/*' 'ijcd/*' --squash >/dev/null 2>&1

rc=0; "$SCRIPT" sync >/dev/null 2>&1 || rc=$?
[[ $rc -ne 0 ]] || fail "sync should exit non-zero when a squash thread conflicts (got $rc)"

jj log --no-graph -r "ijcd/clean" -T '""' >/dev/null 2>&1 \
  || fail "ijcd/clean should squash despite the other thread's conflict"
if jj log --no-graph -r "ijcd/dirty" -T '""' >/dev/null 2>&1; then
  fail "ijcd/dirty should have been rolled back (squash conflict)"
fi

cd / && rm -rf "$repo"; echo "ok: squash_conflict"
