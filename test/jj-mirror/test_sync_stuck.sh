#!/usr/bin/env bash
# test_sync_stuck — a thread whose source diff cannot byte-match on the prime
# base (base divergence, NOT a cherry-pick conflict) rebuilds cleanly but stays
# stale. sync must DETECT this, name the stuck thread + offending file + a fix,
# and exit non-zero — instead of printing "synced N thread(s)" and silently
# leaving the thread stale.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
mk_divergent_thread

set +e
out="$("$SCRIPT" sync 2>&1)"
rc=$?
set -e

[[ $rc -ne 0 ]] || fail "sync should exit non-zero when a thread stays stale after rebuild; rc=$rc, out: $out"
[[ "$out" == *"wip/x"* ]]  || fail "sync should name the stuck thread wip/x: $out"
[[ "$out" == *"cfg"*   ]]  || fail "sync should name the offending file cfg: $out"
[[ "$out" == *"stale"* ]]  || fail "sync should describe the thread as stale: $out"
[[ "$out" == *"local/main"* || "$out" == *"jj-catch-up"* ]] \
  || fail "sync should suggest how to fix the base divergence: $out"

# nothing was silently fixed — status still reports it stale.
st="$("$SCRIPT" status)"
[[ "$st" == *"wip/x"*"stale"* ]] || fail "status should still report wip/x stale: $st"

cd / && rm -rf "$repo"
echo "ok: sync_stuck"
