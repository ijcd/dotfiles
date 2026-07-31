#!/usr/bin/env bash
# test_all — `--all` tugs every workspace's nearest bookmark to its own @-.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

# default workspace: wip/a behind @-
echo a1 > fa  && jj commit -m a1 2>/dev/null; jj bookmark set wip/a -r @- 2>/dev/null
echo a2 > fa2 && jj commit -m a2 2>/dev/null

# second workspace: wip/b behind its @-
ws2="${repo}.ws2"
jj workspace add --name ws2 "$ws2" >/dev/null 2>&1
( cd "$ws2"
  jj new 'root()' >/dev/null 2>&1
  echo b1 > fb  && jj commit -m b1 2>/dev/null; jj bookmark set wip/b -r @- 2>/dev/null
  echo b2 > fb2 && jj commit -m b2 2>/dev/null
)

"$SCRIPT" --all >/dev/null 2>&1
assert_eq "$(cid 'default@-')" "$(cid wip/a)" "wip/a tugged to default @-"
assert_eq "$(cid 'ws2@-')"     "$(cid wip/b)" "wip/b tugged to ws2 @-"

cd / && rm -rf "$repo" "$ws2"; echo "ok: all"
