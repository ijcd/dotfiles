#!/usr/bin/env bash
# test_cull_ownership — Guard 1, default fail-safe (mode A). In a MULTI-LANE repo
# (per-agent bases local/main-<W>), a sourceless prime with NO open PR that we
# cannot prove is ours must be KEPT — the owner is undeterminable, so refuse to
# cull. Contrast test_sync_orphan: a SINGLE-lane repo still auto-culls its own
# leftover (no peer lane could own it).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'base\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
# alice: her base + a live wip
jj new master >/dev/null 2>&1; echo r > pa; jj commit -m ra >/dev/null 2>&1; jj bookmark set local/main-alice -r @- >/dev/null 2>&1
jj new local/main-alice >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/alice-x -r @- >/dev/null 2>&1
# bob: his base exists (peer lane) + a SOURCELESS prime with no open PR. His
# wip/bob-x is gone (merged/removed), so the existing "source exists" guard cannot
# save ijcd/bob-x — only ownership fail-safe can.
jj new master >/dev/null 2>&1; echo r > pb; jj commit -m rb >/dev/null 2>&1; jj bookmark set local/main-bob -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo pb > pbfile; jj commit -m pbob >/dev/null 2>&1; jj bookmark set ijcd/bob-x -r @- >/dev/null 2>&1
jj new @- >/dev/null 2>&1
jj config set --repo jj-mirror.prime-prefix ijcd/ >/dev/null 2>&1
jj config set --repo jj-mirror.source-prefix wip/ >/dev/null 2>&1

# alice syncs against HER base; bob's PR is NOT open.
JJ_MIRROR_SOURCE_ROOT=local/main-alice "$SCRIPT" sync >/dev/null 2>&1

# bob's sourceless prime survives — alice cannot prove it's hers (peer lane exists).
jj log --no-graph -r ijcd/bob-x -T '""' >/dev/null 2>&1 \
  || fail "alice's sync CULLED bob's sourceless ijcd/bob-x (multi-lane => must fail safe)"
# alice's own PR still created.
jj log --no-graph -r ijcd/alice-x -T '""' >/dev/null 2>&1 || fail "alice's PR not created"

cd / && rm -rf "$repo"
echo "ok: cull_ownership"
