#!/usr/bin/env bash
# test_bookmarks — enumeration filters by prefix, ignores others.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# Create three commits, bookmark them wip/a, junk, wip/b
echo one > f && jj commit -m "one" 2>/dev/null
jj bookmark set wip/a -r @- 2>/dev/null
echo two > f && jj commit -m "two" 2>/dev/null
jj bookmark set junk -r @- 2>/dev/null
echo three > f && jj commit -m "three" 2>/dev/null
jj bookmark set wip/b -r @- 2>/dev/null

out="$("$SCRIPT" _dump-bookmarks source 2>&1)"
[[ "$out" == *"wip/a"* ]] || fail "wip/a missing from source list: $out"
[[ "$out" == *"wip/b"* ]] || fail "wip/b missing from source list: $out"
[[ "$out" != *"junk"* ]] || fail "junk should be filtered out: $out"

out="$("$SCRIPT" _dump-bookmarks prime 2>&1)"
[[ -z "$out" ]] || fail "prime list should be empty: $out"

cd / && rm -rf "$repo"
echo "ok: bookmarks"
