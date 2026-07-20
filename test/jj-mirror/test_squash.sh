#!/usr/bin/env bash
# test_squash — a --squash rule collapses the whole branch into ONE dest commit
# carrying the cumulative diff, re-based onto the prime root.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"

echo base > base.txt && jj commit -m "local base" 2>/dev/null
jj bookmark set local/main -r @- 2>/dev/null

jj new local/main 2>/dev/null
echo a > a.txt && jj commit -m c1 2>/dev/null
echo b > b.txt && jj commit -m c2 2>/dev/null
jj bookmark set wip/feat -r @- 2>/dev/null

"$SCRIPT" add 'wip/*' 'ijcd/*' --squash >/dev/null 2>&1
"$SCRIPT" sync

jj log --no-graph -r "ijcd/feat" -T '""' >/dev/null 2>&1 || fail "ijcd/feat missing"
n=$(jj log --no-graph -r "trunk()..ijcd/feat" -T '"x\n"' | grep -c x)
assert_eq "1" "$n" "squash should produce exactly one dest commit"
for f in a.txt b.txt; do
  jj file list -r "ijcd/feat" 2>/dev/null | grep -qx "$f" || fail "ijcd/feat missing $f (cumulative diff)"
done
if jj file list -r "ijcd/feat" 2>/dev/null | grep -qx base.txt; then
  fail "squash dest should not carry the local/main base file"
fi

# Idempotent: a second sync leaves the squashed commit in place.
before=$(jj log --no-graph -r "ijcd/feat" -T 'commit_id.short() ++ "\n"')
"$SCRIPT" sync >/dev/null 2>&1
after=$(jj log --no-graph -r "ijcd/feat" -T 'commit_id.short() ++ "\n"')
assert_eq "$before" "$after" "squash re-sync should be a no-op"

cd / && rm -rf "$repo"
echo "ok: squash"
