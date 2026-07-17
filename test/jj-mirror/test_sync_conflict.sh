#!/usr/bin/env bash
# test_sync_conflict — wip/a is built on top of a non-source "junk" commit
# that edits the same line wip/a edits. sync_thread starts each thread's
# rebuild from trunk() and skips non-source commits, so duplicating wip/a
# straight onto trunk (without junk's edit) can't cleanly reapply — the
# duplicated prime commit comes out conflicted. sync must detect this,
# roll back atomically via `jj op restore`, and exit non-zero.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# junk: not source-prefixed, so sync_thread's rebuild skips over it.
echo "base" > f && jj commit -m "junk" 2>/dev/null
jj bookmark set junk -r @- 2>/dev/null

# wip/a: built on junk, edits the same line junk introduced.
echo "wip-a" > f && jj commit -m "wip/a" 2>/dev/null
jj bookmark set wip/a -r @- 2>/dev/null

set +e
"$SCRIPT" sync
rc=$?
set -e

[[ $rc -ne 0 ]] || fail "sync should have failed on cherry-pick conflict"

# After rollback, no pr/ bookmarks should exist — this is the first (and
# only) sync call, so pre_op is pre-everything.
if jj bookmark list -T 'name ++ "\n"' 2>/dev/null | grep -q '^pr/'; then
  fail "expected all pr/ bookmarks culled by op restore"
fi

cd / && rm -rf "$repo"
echo "ok: sync_conflict"
