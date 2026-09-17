#!/usr/bin/env bash
# test_cull_ledger — Guard 1, mode B (cull-mode=ledger). Even beside a peer lane,
# a lane may reclaim its OWN sourceless leftover — one it recorded building — while
# a prime it never recorded (a peer's) still survives. Opt-in via jj-mirror.cull-mode.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'base\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
# alice: her base + two wips (alice-x stays, alice-gone will be dropped)
jj new master >/dev/null 2>&1; echo r > pa; jj commit -m ra >/dev/null 2>&1; jj bookmark set local/main-alice -r @- >/dev/null 2>&1
jj new local/main-alice >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/alice-x -r @- >/dev/null 2>&1
jj new @- >/dev/null 2>&1; echo g > fg; jj commit -m g >/dev/null 2>&1; jj bookmark set wip/alice-gone -r @- >/dev/null 2>&1
# bob: peer base + a sourceless, non-live prime alice never built
jj new master >/dev/null 2>&1; echo r > pb; jj commit -m rb >/dev/null 2>&1; jj bookmark set local/main-bob -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo pb > pbfile; jj commit -m pbob >/dev/null 2>&1; jj bookmark set ijcd/bob-x -r @- >/dev/null 2>&1
jj new @- >/dev/null 2>&1
jj config set --repo jj-mirror.prime-prefix ijcd/ >/dev/null 2>&1
jj config set --repo jj-mirror.source-prefix wip/ >/dev/null 2>&1

export JJ_MIRROR_SOURCE_ROOT=local/main-alice JJ_MIRROR_CULL_MODE=ledger

# First sync: builds ijcd/alice-x + ijcd/alice-gone and records them in alice's ledger.
"$SCRIPT" sync >/dev/null 2>&1
jj log --no-graph -r ijcd/alice-gone -T '""' >/dev/null 2>&1 || fail "ijcd/alice-gone not built by first sync"

# Alice drops wip/alice-gone (its work merged/abandoned) — the prime is now sourceless.
jj squash --from wip/alice-gone --to wip/alice-x -u >/dev/null 2>&1 || true
jj bookmark delete wip/alice-gone >/dev/null 2>&1

# Second sync (ledger mode): alice reclaims her OWN leftover; bob's survives.
"$SCRIPT" sync >/dev/null 2>&1
if jj log --no-graph -r ijcd/alice-gone -T '""' >/dev/null 2>&1; then
  fail "ledger mode should reclaim alice's own sourceless ijcd/alice-gone"
fi
jj log --no-graph -r ijcd/bob-x -T '""' >/dev/null 2>&1 \
  || fail "ledger mode CULLED bob's ijcd/bob-x — never recorded as alice's"
jj log --no-graph -r ijcd/alice-x -T '""' >/dev/null 2>&1 || fail "alice's still-sourced ijcd/alice-x vanished"

cd / && rm -rf "$repo"
echo "ok: cull_ledger"
