#!/usr/bin/env bash
# test_sync_conflict — a source thread whose cumulative diff cannot apply onto
# the prime root conflicts, and sync rolls the thread back (exit non-zero, no
# prime bookmarks). Under the full-branch model a conflict needs a genuine
# content clash with the prime root: the branch sits on local/main (which
# carries file f) and modifies f, but the prime root trunk() has no f —
# replaying "modify f" onto trunk is a modify/delete conflict.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# local/main base carries f; the prime root trunk() does NOT.
echo base > f && jj commit -m "local base" 2>/dev/null
jj bookmark set local/main -r @- 2>/dev/null

# wip/a on local/main modifies f — its diff can't apply onto trunk (no f).
echo "wip-a" > f && jj commit -m "wip/a" 2>/dev/null
jj bookmark set wip/a -r @- 2>/dev/null

set +e
"$SCRIPT" sync
rc=$?
set -e

[[ $rc -ne 0 ]] || fail "sync should have failed on cherry-pick conflict"

# The conflicting thread was rolled back — no pr/ bookmark survives.
if jj bookmark list -T 'name ++ "\n"' 2>/dev/null | grep -q '^pr/'; then
  fail "expected the conflicting thread's prime bookmark to be rolled back"
fi

cd / && rm -rf "$repo"
echo "ok: sync_conflict"
