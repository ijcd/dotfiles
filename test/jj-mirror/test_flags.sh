#!/usr/bin/env bash
# test_flags — dry-run doesn't mutate; --thread scopes sync.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# Dry-run
repo="$(mkrepo)"
cd "$repo"
echo a > f && jj commit -m "a" >/dev/null 2>&1; jj bookmark set wip/a -r @- >/dev/null 2>&1

out="$("$SCRIPT" sync --dry-run)"
[[ "$out" == *"would create"* ]] || fail "dry-run output should say what it would do: $out"
if jj bookmark list -T 'name ++ "\n"' 2>/dev/null | grep -q '^pr/'; then
  fail "dry-run must not create any pr/ bookmarks"
fi

cd / && rm -rf "$repo"

# --thread scoping
repo="$(mkrepo)"
cd "$repo"
echo a > fa && jj commit -m "a" >/dev/null 2>&1; jj bookmark set wip/a -r @- >/dev/null 2>&1
jj new 'trunk()' -m "b" >/dev/null 2>&1; echo b > fb && jj describe -m "b" >/dev/null 2>&1; jj bookmark set wip/b -r @ >/dev/null 2>&1

"$SCRIPT" sync --thread wip/a >/dev/null 2>&1
jj log --no-graph -r "pr/a" -T '""' >/dev/null 2>&1 || fail "pr/a should exist after scoped sync"
if jj log --no-graph -r "pr/b" -T '""' >/dev/null 2>&1; then
  fail "pr/b should NOT exist — --thread scoped sync to wip/a only"
fi

cd / && rm -rf "$repo"

# --thread on unmatched name: warn, don't silently no-op.
repo="$(mkrepo)"
cd "$repo"
echo a > fa && jj commit -m "a" >/dev/null 2>&1; jj bookmark set wip/a -r @- >/dev/null 2>&1
warn="$("$SCRIPT" sync --thread wip/nope 2>&1)"
[[ "$warn" == *"matched 0"* ]] || fail "--thread with wrong name should warn about 0 matches: $warn"

cd / && rm -rf "$repo"

# Dry-run: previews orphan cull + cascade rebuild (not just direct rebuild).
repo="$(mkrepo)"
cd "$repo"
echo a1 > fa && jj commit -m "a1" >/dev/null 2>&1; jj bookmark set wip/a1 -r @- >/dev/null 2>&1
echo a2 > fb && jj commit -m "a2" >/dev/null 2>&1; jj bookmark set wip/a2 -r @- >/dev/null 2>&1
"$SCRIPT" sync >/dev/null 2>&1

# Delete a source bookmark → its prime becomes orphan.
jj bookmark delete wip/a1 >/dev/null 2>&1
out="$("$SCRIPT" sync --dry-run)"
[[ "$out" == *"would cull orphan pr/a1"* ]] \
  || fail "dry-run should preview orphan cull of pr/a1: $out"
# Restore for the cascade test.
jj bookmark set wip/a1 -r "$(jj log --no-graph -r 'pr/a1' -T 'commit_id.short() ++ "\n"' 2>/dev/null | head -n1)" >/dev/null 2>&1 || true
"$SCRIPT" sync >/dev/null 2>&1 || true

cd / && rm -rf "$repo"

# Dry-run cascade: a diff change in the middle should show downstream as "cascade".
repo="$(mkrepo)"
cd "$repo"
echo a1 > fa && jj commit -m "a1" >/dev/null 2>&1; jj bookmark set wip/a1 -r @- >/dev/null 2>&1
echo a2 > fb && jj commit -m "a2" >/dev/null 2>&1; jj bookmark set wip/a2 -r @- >/dev/null 2>&1
echo a3 > fc && jj commit -m "a3" >/dev/null 2>&1; jj bookmark set wip/a3 -r @- >/dev/null 2>&1
"$SCRIPT" sync >/dev/null 2>&1

# Amend wip/a2's content — a3's diff hash is unchanged, but sync would still
# rebuild pr/a3 because its parent moved. Dry-run must reflect that.
jj edit wip/a2 >/dev/null 2>&1
echo a2-changed > fb
jj new 'trunk()' >/dev/null 2>&1
out="$("$SCRIPT" sync --dry-run)"
[[ "$out" == *"would rebuild pr/a2 (diff changed)"* ]] \
  || fail "dry-run should mark pr/a2 as rebuild: $out"
[[ "$out" == *"would rebuild pr/a3 (cascade)"* ]] \
  || fail "dry-run should mark pr/a3 as cascade rebuild: $out"

cd / && rm -rf "$repo"
echo "ok: flags"
