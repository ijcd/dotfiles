#!/usr/bin/env bash
# test_agent_scope — the mirror enumerates/validates only sources that descend from
# THIS agent's base (source root). Another agent's NON-LINEAR (merge/octopus) branch
# on a different base must not be seen — it must neither abort the linearity check
# nor get mirrored. Regression for the fleet-blocking bug.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'base\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1

# alice: her base + one LINEAR wip branch
jj new master >/dev/null 2>&1; echo r > personal; jj commit -m ra >/dev/null 2>&1; jj bookmark set local/main-alice -r @- >/dev/null 2>&1
jj new local/main-alice >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/alice-x -r @- >/dev/null 2>&1

# bob: his base + a NON-LINEAR (merge) wip branch on a DIFFERENT base
jj new master >/dev/null 2>&1; echo r > personal; jj commit -m rb >/dev/null 2>&1; jj bookmark set local/main-bob -r @- >/dev/null 2>&1
jj new local/main-bob >/dev/null 2>&1; echo b > fb; jj commit -m b1 >/dev/null 2>&1; jj bookmark set wip/bob-a -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo s > fs; jj commit -m side >/dev/null 2>&1; jj bookmark set side -r @- >/dev/null 2>&1
jj new wip/bob-a side >/dev/null 2>&1; jj bookmark set wip/bob-merge -r @ >/dev/null 2>&1   # 2-parent merge — non-linear
jj new @- >/dev/null 2>&1

jj config set --repo jj-mirror.prime-root master >/dev/null 2>&1
jj config set --repo jj-mirror.prime-prefix ijcd/ >/dev/null 2>&1
jj config set --repo jj-mirror.source-prefix wip/ >/dev/null 2>&1

# Sync scoped to alice's base. Bob's non-linear branch is off my base → out of scope,
# so this must NOT die on the linearity precheck.
JJ_MIRROR_SOURCE_ROOT=local/main-alice "$SCRIPT" sync >/dev/null 2>&1 \
  || fail "sync aborted — another agent's non-linear branch was not scoped out"

# my branch mirrored
jj log --no-graph -r ijcd/alice-x -T '""' >/dev/null 2>&1 || fail "my ijcd/alice-x not created"
# bob's branches were NOT enumerated/mirrored under my base
if jj log --no-graph -r 'ijcd/bob-a' -T '""' >/dev/null 2>&1; then fail "bob's wip/bob-a leaked into my sync"; fi
if jj log --no-graph -r 'ijcd/bob-merge' -T '""' >/dev/null 2>&1; then fail "bob's non-linear branch leaked into my sync"; fi

cd / && rm -rf "$repo"
echo "ok: agent_scope"
