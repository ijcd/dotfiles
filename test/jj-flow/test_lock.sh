#!/usr/bin/env bash
# test_lock — #5: mutating jjf verbs serialize on a per-repo advisory lock so two
# workspaces can't interleave bookmark mutation + push. A verb aborts while a LIVE
# holder holds the lock; JJF_NO_LOCK=1 bypasses; a dead holder's lock is stolen.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

command -v shlock >/dev/null 2>&1 || { echo "ok: lock (skipped — no shlock)"; exit 0; }

repo="$(mkrepo)"; cd "$repo"; mk_layers
echo w > fw; jj commit -m w >/dev/null 2>&1; jj bookmark set wip/w -r @- >/dev/null 2>&1; jj new @- >/dev/null 2>&1

lock="$repo/.jj/.jjf-lock"

# A live holder grabs the lock (simulating a peer workspace mid-op).
sleep 30 & holder=$!
shlock -f "$lock" -p "$holder"

# A mutating verb must abort quickly, naming the contention.
set +e
out=$(JJF_LOCK_TIMEOUT=1 "$SCRIPT" mirror -n 2>&1); rc=$?
set -e
(( rc != 0 )) || { kill "$holder" 2>/dev/null; fail "mirror ran while the lock was held (rc=0)"; }
assert_contains "$out" "another jjf op is running" "lock-held abort message" \
  || { kill "$holder" 2>/dev/null; exit 1; }

# JJF_NO_LOCK=1 ignores the held lock.
set +e
JJF_NO_LOCK=1 "$SCRIPT" mirror -n >/dev/null 2>&1; rc=$?
set -e
(( rc == 0 )) || { kill "$holder" 2>/dev/null; fail "JJF_NO_LOCK=1 should bypass the lock (rc=$rc)"; }

# A dead holder's lock is stolen (shlock is PID-aware) — verb proceeds.
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null || true
"$SCRIPT" mirror -n >/dev/null 2>&1 || fail "mirror should acquire a stale (dead-holder) lock"

cd / && rm -rf "$repo"
echo "ok: lock"
