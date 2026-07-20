#!/usr/bin/env bash
# test_full_branch — a TIP-ONLY source bookmark mirrors its WHOLE branch
# commit-for-commit, so a tip that modifies a file its unbookmarked ancestor
# created still applies cleanly on the prime root. This is the lunar conflict
# (only the tip bookmarked) — fixed by full-branch replay.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"

echo base > base.txt && jj commit -m "local base" 2>/dev/null
jj bookmark set local/main -r @- 2>/dev/null

# Unbookmarked ancestor CREATES feature.txt; the tip MODIFIES it. Only tip bookmarked.
jj new local/main 2>/dev/null
echo v1 > feature.txt && jj commit -m "create feature" 2>/dev/null   # no bookmark
echo v2 > feature.txt && jj commit -m "tweak feature"  2>/dev/null
jj bookmark set wip/feat -r @- 2>/dev/null

"$SCRIPT" sync

jj log --no-graph -r "pr/feat" -T '""' >/dev/null 2>&1 \
  || fail "pr/feat missing — full-branch mirror failed"
cf=$(jj log --no-graph -r "pr/feat" -T 'if(conflict,"Y","n") ++ "\n"')
[[ "$cf" == "n" ]] || fail "pr/feat is conflicted — full branch not replayed"

# Both branch commits (create + tweak) mirror onto trunk.
n=$(jj log --no-graph -r "trunk()..pr/feat" -T '"x\n"' | grep -c x)
assert_eq "2" "$n" "prime chain should mirror both branch commits"

# feature.txt present in pr/feat's tree; local/main base file is stripped.
jj file list -r "pr/feat" 2>/dev/null | grep -qx feature.txt \
  || fail "pr/feat missing feature.txt"
if jj file list -r "pr/feat" 2>/dev/null | grep -qx base.txt; then
  fail "pr/feat should not carry the local/main base file base.txt"
fi

cd / && rm -rf "$repo"
echo "ok: full_branch"
