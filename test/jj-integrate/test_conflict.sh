#!/usr/bin/env bash
# test_conflict — when two members modify the same base file incompatibly, the
# merge conflicts: it's REPORTED (not auto-resolved) and the bookmark is still
# created so you can jj-resolve it.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase                                          # base.txt = "base" on local/main
jj new local/main 2>/dev/null; echo AAA > base.txt && jj commit -m a 2>/dev/null; jj bookmark set wip/a -r @- 2>/dev/null
jj new local/main 2>/dev/null; echo BBB > base.txt && jj commit -m b 2>/dev/null; jj bookmark set wip/b -r @- 2>/dev/null

out="$("$SCRIPT" add wip/a wip/b 2>&1)"

exists local/integration || fail "bookmark should still be created despite the conflict"
[[ "$out" == *"CONFLICTED"* ]] || fail "conflict should be reported: $out"
[[ "$(jj log --no-graph -r local/integration -T 'if(conflict,"y","n")' 2>/dev/null | head -n1)" == "y" ]] \
  || fail "the merge should actually be conflicted"

cd / && rm -rf "$repo"; echo "ok: conflict"
