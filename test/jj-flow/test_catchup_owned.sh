#!/usr/bin/env bash
# test_catchup_owned — catchup_owned_wip returns ONLY the wip/* whose nearest
# local/main* base is FLOW_BASE. Sibling bases (base fork = siblings off trunk) and
# legacy wip off a different base are excluded.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'trunk\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1

# my base + 2 wip
jj new master >/dev/null 2>&1; echo m > pm; jj commit -m rm >/dev/null 2>&1; jj bookmark set local/main-me -r @- >/dev/null 2>&1
jj new local/main-me >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/mine-a -r @- >/dev/null 2>&1
jj new local/main-me >/dev/null 2>&1; echo b > fb; jj commit -m b >/dev/null 2>&1; jj bookmark set wip/mine-b -r @- >/dev/null 2>&1

# a peer base (sibling off trunk) + its wip
jj new master >/dev/null 2>&1; echo p > pp; jj commit -m rp >/dev/null 2>&1; jj bookmark set local/main-peer -r @- >/dev/null 2>&1
jj new local/main-peer >/dev/null 2>&1; echo c > fc; jj commit -m c >/dev/null 2>&1; jj bookmark set wip/peer-c -r @- >/dev/null 2>&1

jj config set --repo jj-mirror.prime-root master >/dev/null 2>&1

owned=$(cd "$repo" && FLOW_BASE=local/main-me FLOW_WORK_PREFIX=wip/ \
  bash -c 'source "'"$BIN"'/jjflow-lib.sh"; source "'"$BIN"'/jjflow-catchup.sh"; catchup_owned_wip' | sort | tr '\n' ' ')
assert_eq "wip/mine-a wip/mine-b " "$owned" "owned set is exactly my two wip"

cd / && rm -rf "$repo"
echo "ok: catchup_owned"
