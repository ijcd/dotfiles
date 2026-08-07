#!/usr/bin/env bash
# test_config_layers — flow_load_config resolves the [jj-flow] keys, falling back
# to [jj-mirror]/[jj-integrate] during migration; flow_wip_branches enumerates
# work-prefix bookmarks.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
mk_layers

# Defaults + [jj-mirror] fallback (prime-prefix → pr-prefix).
jj config set --repo jj-mirror.prime-prefix 'ijcd/' >/dev/null 2>&1
jj config set --repo jj-mirror.source-prefix 'wip/'  >/dev/null 2>&1
cfg=$("$SCRIPT" _dump-config)
assert_contains "$cfg" 'base=local/main'   "base fallback"
assert_contains "$cfg" 'work-prefix=wip/'  "work-prefix from source-prefix fallback"
assert_contains "$cfg" 'pr-prefix=ijcd/'   "pr-prefix from prime-prefix fallback"

# Explicit [jj-flow] overrides the fallback.
jj config set --repo jj-flow.pr-prefix 'pr/' >/dev/null 2>&1
cfg=$("$SCRIPT" _dump-config)
assert_contains "$cfg" 'pr-prefix=pr/' "explicit [jj-flow].pr-prefix wins"

# wip enumeration.
jj new local/main >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/alpha -r @- >/dev/null 2>&1
jj new local/main >/dev/null 2>&1; echo b > fb; jj commit -m b >/dev/null 2>&1; jj bookmark set wip/beta  -r @- >/dev/null 2>&1
jj config set --repo jj-flow.pr-prefix 'ijcd/' >/dev/null 2>&1
wip=$("$SCRIPT" _dump-wip)
assert_contains "$wip" 'wip/alpha' "wip/alpha enumerated"
assert_contains "$wip" 'wip/beta'  "wip/beta enumerated"

cd / && rm -rf "$repo"
echo "ok: config_layers"
