#!/usr/bin/env bash
# test_diff_hash — identical diffs hash equal; different diffs hash different.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# Two independent commits with identical content changes.
echo hello > f && jj commit -m "one"
jj bookmark set A -r @-

jj new 'trunk()' -m "sibling"
echo hello > f && jj describe -m "sibling"
jj bookmark set B -r @

ha="$("$SCRIPT" _diff-hash "A")"
hb="$("$SCRIPT" _diff-hash "B")"
[[ -n "$ha" && "$ha" == "$hb" ]] || fail "identical diffs should hash equal: A=$ha B=$hb"

# Now make B different
echo different > f && jj describe -m "sibling"
hb2="$("$SCRIPT" _diff-hash "B")"
[[ "$ha" != "$hb2" ]] || fail "different diffs should hash different: A=$ha B2=$hb2"

cd / && rm -rf "$repo"
echo "ok: diff_hash"
