#!/usr/bin/env bash
# test_status_graph — `jj-flow status --graph` renders the trunk→base→wip spine
# with ──▶ ijcd/* projection edges, the right glyphs, a draft (no-PR) branch, and
# an inline base-divergence note for a stuck branch.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
mk_layers
jj config set --repo jj-mirror.prime-prefix 'ijcd/' >/dev/null 2>&1

# live branch
jj new local/main >/dev/null 2>&1; echo l > fl; jj commit -m l >/dev/null 2>&1; jj bookmark set wip/auth -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo l > fl; jj commit -m pl >/dev/null 2>&1; jj bookmark set ijcd/auth -r @- >/dev/null 2>&1
# draft branch (no PR)
jj new local/main >/dev/null 2>&1; echo s > fs; jj commit -m s >/dev/null 2>&1; jj bookmark set wip/spike -r @- >/dev/null 2>&1
# stuck branch: edits localonly (differs trunk↔base), has a PR bookmark
jj new local/main >/dev/null 2>&1; echo changed > localonly; jj commit -m x >/dev/null 2>&1; jj bookmark set wip/flaky -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo x > fx; jj commit -m px >/dev/null 2>&1; jj bookmark set ijcd/flaky -r @- >/dev/null 2>&1

out=$(JJ_MIRROR_LIVE_PRS="ijcd/auth" "$SCRIPT" status --graph)

assert_contains "$out" 'trunk  master'       "header trunk line"
assert_contains "$out" 'base   local/main'   "header base line"
assert_contains "$out" 'current'             "base sits on trunk here → current"
assert_contains "$out" 'wip/auth'            "auth branch present"
assert_contains "$out" '──▶  ijcd/auth'      "auth PR edge"
assert_contains "$out" '○ wip/spike'         "draft branch: glyph, no edge"
assert_contains "$out" 'localonly'           "stuck divergence note names the file"
assert_contains "$out" 'legend'              "legend present"
# Alignment: every branch edge's ──▶ starts at the same column (exclude the header).
col=$(printf '%s\n' "$out" | grep -E '──▶ +ijcd/' | grep -oE '^.*──▶' | awk '{print length($0)}' | sort -u | wc -l | tr -d ' ')
assert_eq 1 "$col" "all branch ──▶ arrows aligned to one column"

cd / && rm -rf "$repo"
echo "ok: status_graph"
