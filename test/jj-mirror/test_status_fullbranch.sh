#!/usr/bin/env bash
# test_status_fullbranch — status judges a pair by the whole sub-branch, not the
# tip. A tip-only / incomplete prime must read STALE, not ok.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo base > base.txt && jj commit -m base 2>/dev/null; jj bookmark set local/main -r @- 2>/dev/null
# 2-commit branch: c1 adds a.txt (unbookmarked), c2 adds b.txt (tip = wip/feat)
jj new local/main 2>/dev/null; echo a > a.txt && jj commit -m c1 2>/dev/null
echo b > b.txt && jj commit -m c2 2>/dev/null; jj bookmark set wip/feat -r @- 2>/dev/null

# Hand-build a TIP-ONLY prime (as the old engine would): duplicate ONLY the tip
# onto trunk and bookmark it — a clean 1-commit prime missing its ancestor.
tip=$(jj log --no-graph -r "wip/feat" -T 'commit_id.short()' | head -n1)
out=$(jj duplicate "$tip" --destination 'trunk()' 2>&1)
newcid=$(printf '%s\n' "$out" | awk '/^Duplicated/{print $5; exit}')
jj bookmark set pr/feat -r "$newcid" 2>/dev/null

# Old status compared tip diffs and called this "ok"; it must now read "stale".
out="$("$SCRIPT" status)"
[[ "$out" == *"wip/feat"*"stale"* ]] || fail "tip-only prime must read stale, not ok: $out"

# A real full-branch sync makes it genuinely ok.
"$SCRIPT" sync >/dev/null 2>&1
out="$("$SCRIPT" status)"
[[ "$out" == *"wip/feat"*"ok"* ]] || fail "after full sync should be ok: $out"

cd / && rm -rf "$repo"; echo "ok: status_fullbranch"
