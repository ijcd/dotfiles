#!/usr/bin/env bash
# test_live_pr_set — live-PR detection resolves the JJ_MIRROR_LIVE_PRS injection
# seam (space-separated dest bookmark names), and an explicitly-empty env means
# "nothing live" without consulting the forge. This env seam is what every
# merge-mode test uses in place of a real `gh`/network dependency.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# Injected set — exactly those names, one per line.
out=$(JJ_MIRROR_LIVE_PRS="pr/a pr/b" "$SCRIPT" _live-pr-set)
assert_eq $'pr/a\npr/b' "$out" "env-injected live set"

# Explicitly empty env → empty (resolution stops at the env branch, no gh).
out=$(JJ_MIRROR_LIVE_PRS="" "$SCRIPT" _live-pr-set)
assert_eq "" "$out" "empty env → no live members"

# Extra whitespace is tolerated.
out=$(JJ_MIRROR_LIVE_PRS="  pr/x   pr/y " "$SCRIPT" _live-pr-set)
assert_eq $'pr/x\npr/y' "$out" "whitespace-tolerant env set"

cd / && rm -rf "$repo"
echo "ok: live_pr_set"
