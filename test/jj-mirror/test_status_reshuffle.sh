#!/usr/bin/env bash
# test_status_reshuffle — status uses the per-commit positional walk (as sync
# does), not just cumulative-diff+count. A prime whose commits are RESHUFFLED to
# the same net diff and same commit count must read STALE — the old cumulative+
# count check read it "ok" while a real sync would still rebuild.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo base > base.txt && jj commit -m base 2>/dev/null; jj bookmark set local/main -r @- 2>/dev/null
# source: A adds foo, B adds bar (tip). Independent files → order is free to change.
jj new local/main 2>/dev/null; echo foo > foo.txt && jj commit -m A 2>/dev/null
echo bar > bar.txt && jj commit -m B 2>/dev/null; jj bookmark set wip/feat -r @- 2>/dev/null
"$SCRIPT" sync
out="$("$SCRIPT" status)"; [[ "$out" == *"wip/feat"*"ok"* ]] || fail "faithful mirror should be ok: $out"

# Hand-build a RESHUFFLED prime: same two files, opposite commit order (bar then
# foo). Same cumulative diff and same count as the source, but different per commit.
jj bookmark delete pr/feat >/dev/null 2>&1
jj new 'trunk()' 2>/dev/null; echo bar > bar.txt && jj commit -m pbar 2>/dev/null
echo foo > foo.txt && jj commit -m pfoo 2>/dev/null; jj bookmark set pr/feat -r @- 2>/dev/null
jj new 'trunk()' 2>/dev/null

out="$("$SCRIPT" status)"
[[ "$out" == *"wip/feat"*"stale"* ]] || fail "reshuffled prime (same net + count) must read stale: $out"

cd / && rm -rf "$repo"; echo "ok: status_reshuffle"
