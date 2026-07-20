#!/usr/bin/env bash
# test_dest_default — an EXACT rule with no dest (and no covering glob) defaults to
# <prime-prefix><suffix>, and two such rules must not collide on a bare prefix.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo 1 > f1 && jj commit -m foo 2>/dev/null; jj bookmark set wip/foo -r @- 2>/dev/null
jj new 'trunk()' 2>/dev/null; echo 2 > f2 && jj commit -m bar 2>/dev/null; jj bookmark set wip/bar -r @- 2>/dev/null

# Two independent exact rules, neither with a dest, no covering glob.
"$SCRIPT" add 'wip/foo' >/dev/null 2>&1
"$SCRIPT" add 'wip/bar' >/dev/null 2>&1
"$SCRIPT" sync

# Each must get its own <prime-prefix><suffix>, not a bare "pr/".
jj log --no-graph -r "pr/foo" -T '""' >/dev/null 2>&1 || fail "pr/foo missing (exact no-dest default)"
jj log --no-graph -r "pr/bar" -T '""' >/dev/null 2>&1 || fail "pr/bar missing (exact no-dest default)"
# And they must be distinct — the old fallback collapsed both to a bare 'pr/'.
cf=$(jj log --no-graph -r "pr/foo" -T 'commit_id.short()' | head -n1)
cb=$(jj log --no-graph -r "pr/bar" -T 'commit_id.short()' | head -n1)
[[ "$cf" != "$cb" ]] || fail "pr/foo and pr/bar collided (bare-prefix dest bug)"

cd / && rm -rf "$repo"; echo "ok: dest_default"
