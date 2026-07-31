#!/usr/bin/env bash
# test_glob — a GLOB scopes the current tug: it moves the nearest wip/* bookmark
# and leaves a *nearer* non-matching bookmark untouched.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"

echo a1 > f1 && jj commit -m a1 2>/dev/null; jj bookmark set wip/a -r @- 2>/dev/null   # wip/a at a1
echo a2 > f2 && jj commit -m a2 2>/dev/null; jj bookmark set other -r @- 2>/dev/null   # other at a2 (nearer)
echo a3 > f3 && jj commit -m a3 2>/dev/null                                            # @- = a3
before_other="$(cid other)"

"$SCRIPT" 'wip/*' >/dev/null 2>&1
assert_eq "$(cid '@-')" "$(cid wip/a)" "wip/a tugged up to @-"
assert_eq "$before_other" "$(cid other)" "nearer non-matching 'other' must NOT move"

cd / && rm -rf "$repo"; echo "ok: glob"
