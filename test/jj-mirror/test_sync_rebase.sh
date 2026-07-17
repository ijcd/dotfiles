#!/usr/bin/env bash
# test_sync_rebase — source bookmarks sit on local/main (a base beyond trunk);
# the prime chain must be re-based onto trunk (source-root ≠ prime-root), with
# local/main's base commit stripped. Exercises the coalesce(present(local/main),
# trunk()) source-root default's local/main-present branch (other tests hit the
# trunk() fallback).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# Local-only base on top of trunk, bookmarked local/main (the default source-root).
echo localonly > localonly && jj commit -m "local base" 2>/dev/null
jj bookmark set local/main -r @- 2>/dev/null

# Source chain on top of local/main.
echo a1 > f && jj commit -m "a1" 2>/dev/null; jj bookmark set wip/a1 -r @- 2>/dev/null
echo a2 > f && jj commit -m "a2" 2>/dev/null; jj bookmark set wip/a2 -r @- 2>/dev/null

# Sanity: config should detect local/main as the source root.
"$SCRIPT" _dump-config | grep -q '^source-root=coalesce' \
  || fail "source-root default not the coalesce revset"

"$SCRIPT" sync

# pr/a1's parent must be trunk() (prime-root), NOT local/main — base stripped.
trunk=$(jj log --no-graph -r "trunk()"    -T 'commit_id.short() ++ "\n"')
lmain=$(jj log --no-graph -r "local/main" -T 'commit_id.short() ++ "\n"')
p1=$(jj log --no-graph -r "pr/a1-"        -T 'commit_id.short() ++ "\n"')
assert_eq "$trunk" "$p1" "pr/a1 re-based onto trunk"
[[ "$p1" != "$lmain" ]] || fail "pr/a1 sits on local/main — base not stripped"

# local/main's base file must NOT be in the prime tree.
if jj file list -r "pr/a2" 2>/dev/null | grep -qx 'localonly'; then
  fail "pr/a2 tree still contains local/main base file 'localonly'"
fi

cd / && rm -rf "$repo"
echo "ok: sync_rebase"
