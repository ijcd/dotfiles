#!/usr/bin/env bash
# test_stale_safe — `--all` runs over a STALE workspace without a stale error (it
# reads `<ws>@` by revset, never snapshots that workspace) and still tugs the
# clean workspaces — the loop isn't aborted by the stale one.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

# default (clean): wip/a behind @- — SHOULD tug
echo a1 > fa  && jj commit -m a1 2>/dev/null; jj bookmark set wip/a -r @- 2>/dev/null
echo a2 > fa2 && jj commit -m a2 2>/dev/null

# ws2: a wip/b chain, ws2@ on b2
ws2="${repo}.ws2"
jj workspace add --name ws2 "$ws2" >/dev/null 2>&1
( cd "$ws2"
  jj new 'root()' >/dev/null 2>&1
  echo b1 > fb  && jj commit -m b1 2>/dev/null; jj bookmark set wip/b -r @- 2>/dev/null
  echo b2 > fb2 && jj commit -m b2 2>/dev/null
)

# Force ws2 stale WITHOUT moving default's @: rebase ws2@ onto root() — a divergent
# tree change ({fb,fb2} -> {}) jj can't silently reconcile.
jj rebase -r 'ws2@' -d 'root()' 2>/dev/null
# jj status on a stale workspace EXITS non-zero — capture output (|| true) and
# match, rather than piping (pipefail would mask grep's success).
st="$( cd "$ws2" && jj status 2>&1 || true )"
[[ "$st" == *[Ss]tale* ]] || fail "precondition: ws2 should be stale"

out="$("$SCRIPT" --all 2>&1)"
[[ "$out" != *[Ss]tale* ]] || fail "jj-tug must not surface a stale error: $out"
# the loop ran past the stale ws2 and tugged the clean default workspace
assert_eq "$(cid 'default@-')" "$(cid wip/a)" "clean workspace still tugged (loop not aborted by stale ws2)"

cd / && rm -rf "$repo" "$ws2"; echo "ok: stale_safe"
