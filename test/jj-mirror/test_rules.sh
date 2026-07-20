#!/usr/bin/env bash
# test_rules — explicit registry: add/rm/list, specificity (exact > glob),
# rename, and exclusion carve-out (glob add then rm specific).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"

echo a > fa && jj commit -m a 2>/dev/null; jj bookmark set wip/a -r @- 2>/dev/null
jj new 'trunk()' 2>/dev/null; echo x > fx && jj commit -m x 2>/dev/null; jj bookmark set feat/x -r @- 2>/dev/null

# Register a glob for feat/* only. Now feat/x mirrors; wip/a does NOT (no wip rule).
"$SCRIPT" add 'feat/*' 'mir/*' >/dev/null 2>&1
lst="$("$SCRIPT" list)"
[[ "$lst" == *"feat/*"* && "$lst" == *"mir/*"* ]] || fail "list should show the feat rule: $lst"
src="$("$SCRIPT" _dump-bookmarks source)"
[[ "$src" == *"feat/x"* ]] || fail "feat/x should be a source: $src"
[[ "$src" != *"wip/a"* ]]  || fail "wip/a should NOT mirror with no wip rule: $src"

# Rename: an exact rule beats the glob (most-specific wins).
"$SCRIPT" add 'feat/x' 'mir/renamed' >/dev/null 2>&1
"$SCRIPT" sync >/dev/null 2>&1
jj log --no-graph -r "mir/renamed" -T '""' >/dev/null 2>&1 || fail "rename rule not applied (mir/renamed missing)"
if jj log --no-graph -r "mir/x" -T '""' >/dev/null 2>&1; then fail "glob dest mir/x should be overridden by the exact rename"; fi

# Exclusion carve-out: add a family glob, then rm one member.
"$SCRIPT" add 'wip/*' >/dev/null 2>&1
src="$("$SCRIPT" _dump-bookmarks source)"
[[ "$src" == *"wip/a"* ]] || fail "wip/a should mirror after 'add wip/*': $src"
"$SCRIPT" rm 'wip/a' >/dev/null 2>&1
src="$("$SCRIPT" _dump-bookmarks source)"
[[ "$src" != *"wip/a"* ]] || fail "wip/a should be carved out after 'rm wip/a': $src"

# Re-adding reverses the exclusion.
"$SCRIPT" add 'wip/a' >/dev/null 2>&1
src="$("$SCRIPT" _dump-bookmarks source)"
[[ "$src" == *"wip/a"* ]] || fail "'add wip/a' should reverse the carve-out: $src"

cd / && rm -rf "$repo"
echo "ok: rules"
