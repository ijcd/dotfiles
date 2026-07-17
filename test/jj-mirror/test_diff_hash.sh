#!/usr/bin/env bash
# test_diff_hash — identical diffs hash equal; different diffs hash different.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# Silence jj setup chatter — assertions still run; only cosmetic output suppressed.
# Two independent commits with identical content changes.
echo hello > f && jj commit -m "one" >/dev/null 2>&1
jj bookmark set A -r @- >/dev/null 2>&1

jj new 'trunk()' -m "sibling" >/dev/null 2>&1
echo hello > f && jj describe -m "sibling" >/dev/null 2>&1
jj bookmark set B -r @ >/dev/null 2>&1

ha="$("$SCRIPT" _diff-hash "A")"
hb="$("$SCRIPT" _diff-hash "B")"
[[ -n "$ha" && "$ha" == "$hb" ]] || fail "identical diffs should hash equal: A=$ha B=$hb"

# Now make B different
echo different > f && jj describe -m "sibling" >/dev/null 2>&1
hb2="$("$SCRIPT" _diff-hash "B")"
[[ "$ha" != "$hb2" ]] || fail "different diffs should hash different: A=$ha B2=$hb2"

cd / && rm -rf "$repo"
echo "ok: diff_hash"
