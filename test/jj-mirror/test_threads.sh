#!/usr/bin/env bash
# test_threads — thread detection groups source bookmarks by ancestry.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# Thread 1: linear stack off root — wip/a1, wip/a2, wip/a3
echo a1 > fa && jj commit -m "a1" 2>/dev/null; jj bookmark set wip/a1 -r @- 2>/dev/null
echo a2 > fa && jj commit -m "a2" 2>/dev/null; jj bookmark set wip/a2 -r @- 2>/dev/null
echo a3 > fa && jj commit -m "a3" 2>/dev/null; jj bookmark set wip/a3 -r @- 2>/dev/null

# Thread 2: another stack off root (sibling to a1's chain)
jj new 'trunk()' -m "b1" 2>/dev/null
echo b1 > fb && jj describe -m "b1" 2>/dev/null; jj bookmark set wip/b1 -r @ 2>/dev/null
jj commit -m "sep" 2>/dev/null    # move to child
echo b2 > fb && jj describe -m "b2" 2>/dev/null; jj bookmark set wip/b2 -r @ 2>/dev/null

# Non-source bookmark on the a-chain, should be ignored
jj bookmark set junk -r wip/a2 2>/dev/null

out="$("$SCRIPT" _dump-threads 2>&1)"
# Expect two lines. Order between threads not asserted; order within is.
echo "$out" | grep -qE "^wip/a3\swip/a1\|wip/a2\|wip/a3$" \
  || fail "thread a not detected in expected order: $out"
echo "$out" | grep -qE "^wip/b2\swip/b1\|wip/b2$" \
  || fail "thread b not detected in expected order: $out"

cd / && rm -rf "$repo"
echo "ok: threads"
