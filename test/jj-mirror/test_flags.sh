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
echo "ok: flags"
