#!/usr/bin/env bash
# test_all_glob_safety — `--all` (default glob wip/*) must SKIP a workspace parked
# on local/main with no wip/* branch, never dragging local/main forward.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo base > base.txt && jj commit -m base 2>/dev/null; jj bookmark set local/main -r @- 2>/dev/null
# default workspace: straight on local/main, no wip
jj new 'local/main' 2>/dev/null
lm_before="$(cid local/main)"

# ws2: has a wip/b
ws2="${repo}.ws2"
jj workspace add --name ws2 "$ws2" >/dev/null 2>&1
( cd "$ws2"
  jj new 'local/main' >/dev/null 2>&1
  echo b > fb  && jj commit -m b 2>/dev/null; jj bookmark set wip/b -r @- 2>/dev/null
  echo b2 > fb2 && jj commit -m b2 2>/dev/null
)

"$SCRIPT" --all >/dev/null 2>&1
assert_eq "$lm_before" "$(cid local/main)" "local/main must NOT be dragged (glob safety rail)"
assert_eq "$(cid 'ws2@-')" "$(cid wip/b)"  "wip/b still tugged in ws2"

cd / && rm -rf "$repo" "$ws2"; echo "ok: all_glob_safety"
