#!/usr/bin/env bash
# test_cull_repo_wide — #1: `sync --repo-wide` is the explicit reaper. It relaxes
# Guard 1 (ownership) to cull a genuinely-dead orphan the default mode keeps — but
# Guard 2 STILL holds: a prime backing an open PR is untouchable even repo-wide.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'base\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
# alice + a peer lane bob, so the default mode would fail-safe (keep).
jj new master >/dev/null 2>&1; echo r > pa; jj commit -m ra >/dev/null 2>&1; jj bookmark set local/main-alice -r @- >/dev/null 2>&1
jj new local/main-alice >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/alice-x -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo r > pb; jj commit -m rb >/dev/null 2>&1; jj bookmark set local/main-bob -r @- >/dev/null 2>&1
# A genuinely-dead orphan: sourceless, no open PR, nobody's ledger.
jj new master >/dev/null 2>&1; echo d > fd; jj commit -m dead >/dev/null 2>&1; jj bookmark set ijcd/dead -r @- >/dev/null 2>&1
# A sourceless orphan that STILL backs an open PR — Guard 2 must protect it.
jj new master >/dev/null 2>&1; echo l > fl; jj commit -m liveorphan >/dev/null 2>&1; jj bookmark set ijcd/live-orphan -r @- >/dev/null 2>&1
jj new @- >/dev/null 2>&1
jj config set --repo jj-mirror.prime-prefix ijcd/ >/dev/null 2>&1
jj config set --repo jj-mirror.source-prefix wip/ >/dev/null 2>&1

export JJ_MIRROR_SOURCE_ROOT=local/main-alice JJ_MIRROR_LIVE_PRS="ijcd/live-orphan"

"$SCRIPT" sync --repo-wide >/dev/null 2>&1

# The dead orphan is reaped.
if jj log --no-graph -r ijcd/dead -T '""' >/dev/null 2>&1; then
  fail "--repo-wide should reap the dead orphan ijcd/dead"
fi
# The open-PR orphan survives even under --repo-wide (Guard 2 never yields).
jj log --no-graph -r ijcd/live-orphan -T '""' >/dev/null 2>&1 \
  || fail "--repo-wide CULLED ijcd/live-orphan — Guard 2 must hold even repo-wide"

cd / && rm -rf "$repo"
echo "ok: cull_repo_wide"
