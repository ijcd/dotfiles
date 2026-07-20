#!/usr/bin/env bash
# test_dest_inherit — a more-specific rule that omits `dest` inherits the dest
# mapping of the glob it overrides, not the global prime-prefix.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo base > base.txt && jj commit -m base 2>/dev/null; jj bookmark set local/main -r @- 2>/dev/null
jj new local/main 2>/dev/null; echo h > h.txt && jj commit -m hotfix 2>/dev/null; jj bookmark set wip/hotfix -r @- 2>/dev/null

"$SCRIPT" add 'wip/*' 'ijcd/*' >/dev/null 2>&1        # family → ijcd/*
"$SCRIPT" add 'wip/hotfix' --squash >/dev/null 2>&1   # exact, NO dest → inherit ijcd/hotfix
"$SCRIPT" sync

jj log --no-graph -r "ijcd/hotfix" -T '""' >/dev/null 2>&1 \
  || fail "exact rule should inherit the glob's dest (expected ijcd/hotfix)"
if jj log --no-graph -r "pr/hotfix" -T '""' >/dev/null 2>&1; then
  fail "should NOT fall back to the global prime-prefix (pr/hotfix)"
fi
# and it still squashes
n=$(jj log --no-graph -r "trunk()..ijcd/hotfix" -T '"x\n"' | grep -c x)
assert_eq "1" "$n" "hotfix rule should still squash to one commit"

cd / && rm -rf "$repo"; echo "ok: dest_inherit"
