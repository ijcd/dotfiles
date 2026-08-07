#!/usr/bin/env bash
# test_status — `jj-flow status` renders the trunk/base header and one row per
# wip/* branch with the right state glyph, PR, drift, and a `next` hint.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
mk_layers
jj config set --repo jj-mirror.prime-prefix 'ijcd/' >/dev/null 2>&1

jj new local/main >/dev/null 2>&1; echo d > fd; jj commit -m d >/dev/null 2>&1; jj bookmark set wip/draft -r @- >/dev/null 2>&1
jj new local/main >/dev/null 2>&1; echo m > fm; jj commit -m m >/dev/null 2>&1; jj bookmark set wip/mir -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo m > fm; jj commit -m pm >/dev/null 2>&1; jj bookmark set ijcd/mir -r @- >/dev/null 2>&1
jj new local/main >/dev/null 2>&1; echo l > fl; jj commit -m l >/dev/null 2>&1; jj bookmark set wip/liv -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo l > fl; jj commit -m pl >/dev/null 2>&1; jj bookmark set ijcd/liv -r @- >/dev/null 2>&1

out=$(JJ_MIRROR_LIVE_PRS="ijcd/liv" JJFLOW_MERGED_PRS="" "$SCRIPT" status)

assert_contains "$out" 'trunk'  "header has trunk"
assert_contains "$out" 'master' "trunk labelled master"
assert_contains "$out" 'local/main' "header has base"
# draft row: ○ glyph, no PR.
assert_contains "$out" '○ draft' "draft glyph"
# mirrored row: ◐, ijcd/mir, and a push hint.
assert_contains "$out" '◐ mirrored' "mirrored glyph"
assert_contains "$out" 'ijcd/mir' "mirrored PR bookmark"
# live row: ●.
assert_contains "$out" '● live' "live glyph"
# next hints mention push (mirrored present).
assert_contains "$out" 'push' "next hint: push"

cd / && rm -rf "$repo"
echo "ok: status"
