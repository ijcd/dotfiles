#!/usr/bin/env bash
# test_stacked — a multi-bookmark stack WITH unbookmarked commits between the
# bookmarks mirrors to a matching dest stack; each dest carries its own
# unbookmarked ancestors and the ancestry (stacked-PR topology) is preserved.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo base > base.txt && jj commit -m base 2>/dev/null; jj bookmark set local/main -r @- 2>/dev/null
# c1 (unbookmarked), c2 = wip/a, c3 (unbookmarked), c4 = wip/b — independent files.
jj new local/main 2>/dev/null; echo 1 > f1.txt && jj commit -m c1 2>/dev/null
echo 2 > f2.txt && jj commit -m c2 2>/dev/null; jj bookmark set wip/a -r @- 2>/dev/null
echo 3 > f3.txt && jj commit -m c3 2>/dev/null
echo 4 > f4.txt && jj commit -m c4 2>/dev/null; jj bookmark set wip/b -r @- 2>/dev/null

"$SCRIPT" sync

for b in pr/a pr/b; do
  jj log --no-graph -r "$b" -T '""' >/dev/null 2>&1 || fail "$b missing"
  cf=$(jj log --no-graph -r "$b" -T 'if(conflict,"Y","n")'); [[ "$cf" == "n" ]] || fail "$b conflicted"
done
# pr/a carries its unbookmarked ancestor: trunk()..pr/a == 2 commits (c1',c2')
na=$(jj log --no-graph -r "trunk()..pr/a" -T '"x\n"' | grep -c x)
assert_eq "2" "$na" "pr/a should carry c1 + c2"
# pr/b is the full stack: trunk()..pr/b == 4 commits
nb=$(jj log --no-graph -r "trunk()..pr/b" -T '"x\n"' | grep -c x)
assert_eq "4" "$nb" "pr/b should carry c1..c4"
# stacked: pr/a is an ancestor of pr/b
m=$(jj log --no-graph -r "pr/a & ::pr/b" -T '"x\n"' | grep -c x || true)
[[ "$m" -ge 1 ]] || fail "pr/a should be an ancestor of pr/b (stacked topology)"

cd / && rm -rf "$repo"; echo "ok: stacked"
