#!/usr/bin/env bash
# test_cull_scope — a sync scoped to agent alice's base must NOT cull agent bob's
# ijcd/* PR bookmarks. The orphan cull only removes a prime whose source bookmark
# is gone REPO-WIDE (wip/bob-x still exists → ijcd/bob-x survives).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'base\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
# alice: base + wip
jj new master >/dev/null 2>&1; echo r > personal; jj commit -m ra >/dev/null 2>&1; jj bookmark set local/main-alice -r @- >/dev/null 2>&1
jj new local/main-alice >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/alice-x -r @- >/dev/null 2>&1
# bob: base + wip + an existing PR bookmark on master
jj new master >/dev/null 2>&1; echo r > personal; jj commit -m rb >/dev/null 2>&1; jj bookmark set local/main-bob -r @- >/dev/null 2>&1
jj new local/main-bob >/dev/null 2>&1; echo b > fb; jj commit -m b >/dev/null 2>&1; jj bookmark set wip/bob-x -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo pb > pb; jj commit -m pbob >/dev/null 2>&1; jj bookmark set ijcd/bob-x -r @- >/dev/null 2>&1
jj new @- >/dev/null 2>&1
jj config set --repo jj-mirror.prime-root master >/dev/null 2>&1
jj config set --repo jj-mirror.prime-prefix ijcd/ >/dev/null 2>&1
jj config set --repo jj-mirror.source-prefix wip/ >/dev/null 2>&1

# alice syncs against HER base
JJ_MIRROR_SOURCE_ROOT=local/main-alice "$SCRIPT" sync >/dev/null 2>&1

# bob's PR bookmark must survive (wip/bob-x still exists)
jj log --no-graph -r ijcd/bob-x -T '""' >/dev/null 2>&1 || fail "alice's sync CULLED bob's ijcd/bob-x"
# alice's own PR created
jj log --no-graph -r ijcd/alice-x -T '""' >/dev/null 2>&1 || fail "alice's PR not created"

cd / && rm -rf "$repo"
echo "ok: cull_scope"
