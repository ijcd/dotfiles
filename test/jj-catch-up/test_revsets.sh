#!/usr/bin/env bash
# test_revsets — the catch-up rebase revsets honor the [jj-flow] base override, so
# a fleet can isolate onto test/main with one config key (not a 3-file edit).
set -uo pipefail
source "$(dirname "$0")/lib.sh"
source "$BIN/jjflow-lib.sh"
source "$BIN/jjflow-catchup.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'trunk\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo lo > lo; jj commit -m lb >/dev/null 2>&1; jj bookmark set local/main -r @- >/dev/null 2>&1
# FLOW_TRUNK left at its default trunk() — the revset helpers just FORMAT the
# string, they don't evaluate it, so the label is what we assert.

# default base = local/main
flow_load_config
assert_eq "roots(trunk()..local/main)" "$(catchup_private_root)" "default private-root revset"
assert_contains "$(catchup_mine)" 'descendants(trunk()..local/main) ~ local/main' "default mine revset"

# base override → test/main flows through EVERY revset, no hardcoded local/main
jj config set --repo jj-flow.base test/main >/dev/null 2>&1
flow_load_config
assert_eq "roots(trunk()..test/main)" "$(catchup_private_root)" "base override in private-root"
assert_contains "$(catchup_mine)" 'test/main' "base override in mine"
[[ "$(catchup_mine)" != *local/main* ]] || fail "base override still references local/main"

cd / && rm -rf "$repo"
echo "ok: revsets"
