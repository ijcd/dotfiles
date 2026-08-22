#!/usr/bin/env bash
# test_source_root_env — JJ_MIRROR_SOURCE_ROOT (env) overrides the source root, so
# jj-flow can base-strip a PR against the CURRENT agent's base (local/main-<W>)
# without mutating repo-shared config. The PR must contain only the feature
# commit(s), not the agent's recipe.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'base\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
# alice's base = recipe on master; feature on top
jj new master >/dev/null 2>&1; echo recipe > personal; jj commit -m recipe-a >/dev/null 2>&1; jj bookmark set local/main-alice -r @- >/dev/null 2>&1
jj new local/main-alice >/dev/null 2>&1; echo feat > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/alice-x -r @- >/dev/null 2>&1
jj new @- >/dev/null 2>&1
jj config set --repo jj-mirror.prime-root master >/dev/null 2>&1
jj config set --repo jj-mirror.prime-prefix ijcd/ >/dev/null 2>&1
jj config set --repo jj-mirror.source-prefix wip/ >/dev/null 2>&1

JJ_MIRROR_SOURCE_ROOT=local/main-alice "$SCRIPT" sync >/dev/null 2>&1

jj log --no-graph -r ijcd/alice-x -T '""' >/dev/null 2>&1 || fail "ijcd/alice-x not created"
jj file list -r ijcd/alice-x | grep -qx fa || fail "PR missing the feature file"
if jj file list -r ijcd/alice-x | grep -qx personal; then fail "recipe file leaked into the PR (base not stripped against alice's base)"; fi

cd / && rm -rf "$repo"
echo "ok: source_root_env"
