#!/usr/bin/env bash
# test_rules_3level — three overlapping rules resolve by specificity across all
# three levels: a broad glob, a narrower glob (wins over the broad one), and an
# exact exclusion carve-out.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo o > fo && jj commit -m other 2>/dev/null; jj bookmark set wip/other -r @- 2>/dev/null
jj new 'trunk()' 2>/dev/null; echo y > fy && jj commit -m fy 2>/dev/null; jj bookmark set wip/feat-y -r @- 2>/dev/null
jj new 'trunk()' 2>/dev/null; echo x > fx && jj commit -m fx 2>/dev/null; jj bookmark set wip/feat-x -r @- 2>/dev/null

"$SCRIPT" add 'wip/*' 'a/*' >/dev/null 2>&1        # broad
"$SCRIPT" add 'wip/feat-*' 'b/*' >/dev/null 2>&1   # narrower — beats broad for feat-*
"$SCRIPT" rm 'wip/feat-x' >/dev/null 2>&1           # exact exclusion carve-out

src="$("$SCRIPT" _dump-bookmarks source)"
[[ "$src" == *"wip/other"*  ]] || fail "wip/other should mirror (broad glob): $src"
[[ "$src" == *"wip/feat-y"* ]] || fail "wip/feat-y should mirror (narrower glob): $src"
[[ "$src" != *"wip/feat-x"* ]] || fail "wip/feat-x should be excluded (exact carve-out): $src"

"$SCRIPT" sync >/dev/null 2>&1
# The dest '*' maps to what the SOURCE '*' captured: wip/*→a/* gives a/other;
# the narrower wip/feat-*→b/* captures just "y", so wip/feat-y → b/y.
jj log --no-graph -r "a/other" -T '""' >/dev/null 2>&1 || fail "wip/other should map to a/other (broad)"
jj log --no-graph -r "b/y"     -T '""' >/dev/null 2>&1 || fail "wip/feat-y should map to b/y (narrower wins)"
if jj log --no-graph -r "a/feat-y" -T '""' >/dev/null 2>&1; then fail "narrower must win — a/feat-y must not exist"; fi
if jj log --no-graph -r "a/feat-x" -T '""' >/dev/null 2>&1; then fail "feat-x excluded — a/feat-x must not exist"; fi
if jj log --no-graph -r "b/x" -T '""' >/dev/null 2>&1; then fail "feat-x excluded — b/x must not exist"; fi

cd / && rm -rf "$repo"; echo "ok: rules_3level"
