#!/usr/bin/env bash
# test_sync_insert — insert a source bookmark in the middle; prime gets a new
# middle commit and downstream cascades.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
echo a1 > f && jj commit -m "a1" >/dev/null 2>&1; jj bookmark set wip/a1 -r @- >/dev/null 2>&1
echo a3 > f && jj commit -m "a3" >/dev/null 2>&1; jj bookmark set wip/a3 -r @- >/dev/null 2>&1
"$SCRIPT" sync
before3=$(jj log --no-graph -r "pr/a3" -T 'commit_id.short() ++ "\n"')

# Insert wip/a2 between wip/a1 and wip/a3
jj new -A wip/a1 -m "a2" >/dev/null 2>&1
echo a2 > f && jj describe -m "a2" >/dev/null 2>&1
jj bookmark set wip/a2 -r @ >/dev/null 2>&1
# Rebase wip/a3 to sit on top of wip/a2
jj rebase -s "wip/a3" -d "wip/a2" >/dev/null 2>&1
jj new "trunk()" >/dev/null 2>&1    # move working copy out of the way

"$SCRIPT" sync

# Expect three prime bookmarks now
for name in pr/a1 pr/a2 pr/a3; do
  jj log --no-graph -r "$name" -T '""' >/dev/null 2>&1 \
    || fail "$name bookmark missing after insert"
done

# pr/a3 should have moved (new parent = pr/a2)
after3=$(jj log --no-graph -r "pr/a3" -T 'commit_id.short() ++ "\n"')
[[ "$before3" != "$after3" ]] || fail "pr/a3 should have moved after middle-insert"

pa3=$(jj log --no-graph -r "pr/a3-" -T 'commit_id.short() ++ "\n"')
ca2=$(jj log --no-graph -r "pr/a2"  -T 'commit_id.short() ++ "\n"')
assert_eq "$ca2" "$pa3" "pr/a3 parent should be pr/a2"

cd / && rm -rf "$repo"
echo "ok: sync_insert"
