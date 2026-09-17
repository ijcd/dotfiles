#!/usr/bin/env bash
# test_cull_open_pr — THE INCIDENT (2026-09-12): a prime backing an OPEN PR must
# NEVER be culled, even when it has no source thread at all (a standalone ijcd/*
# created directly, not mirrored from wip/*). Five open PRs were closed because the
# orphan cull abandoned exactly such primes. Guard 2: dest_is_live => keep, always.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'base\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1

# A live wip thread, so the sync has real work (and the cull actually runs).
jj new master >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1
jj bookmark set wip/alice-x -r @- >/dev/null 2>&1

# A standalone prime on master with NO wip/orphan source anywhere — the shape of
# the five branches the incident abandoned.
jj new master >/dev/null 2>&1; echo o > fo; jj commit -m orphan >/dev/null 2>&1
jj bookmark set pr/orphan -r @- >/dev/null 2>&1
jj new @- >/dev/null 2>&1

jj config set --repo jj-mirror.source-root master >/dev/null 2>&1

# pr/orphan's PR is OPEN (inject via the seam the mirror already honors).
export JJ_MIRROR_LIVE_PRS="pr/orphan"

# A routine sync (no --thread) runs the repo-wide orphan cull.
"$SCRIPT" sync >/dev/null 2>&1

# The open-PR-backed prime must survive.
jj log --no-graph -r pr/orphan -T '""' >/dev/null 2>&1 \
  || fail "orphan cull DELETED pr/orphan — it backs an OPEN PR (the 2026-09-12 incident)"

cd / && rm -rf "$repo"
echo "ok: cull_open_pr"
