#!/usr/bin/env bash
# test_refresh — the refresh module: help renders, a clean single-workspace repo
# reports the all-clear, and a WIP workspace is reported (parked) with a next-step.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

# help
assert_contains "$("$SCRIPT" -h 2>&1)" 'refresh stale jj workspaces' "refresh help renders"

# clean repo, only the default workspace, @ empty → all-clear
repo="$(mkrepo)"; cd "$repo"
printf 'x\n' > f; jj commit -m M0 >/dev/null 2>&1
out=$("$SCRIPT" 2>&1)
assert_contains "$out" 'all workspaces clean and current' "clean repo → all-clear"

# park WIP in @ (current workspace) → reported as parked, with a next-step
echo dirty > wipfile
out=$("$SCRIPT" 2>&1)
assert_contains "$out" 'has WIP' "WIP in current workspace is reported"
assert_contains "$out" 'next steps' "next-steps summary shown when there's WIP"

cd / && rm -rf "$repo"
echo "ok: refresh"
