#!/usr/bin/env bash
# test_custom — a custom bookmark name AND custom base are honored end-to-end.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase mybase                                   # base commit bookmarked 'mybase'
jj config set --repo jj-integrate.bookmark foo/integ 2>/dev/null
jj config set --repo jj-integrate.base     mybase    2>/dev/null
mkwip wip/a mybase                              # wip/a off the custom base

"$SCRIPT" add wip/a >/dev/null 2>&1
exists foo/integ || fail "custom bookmark foo/integ should be created"
has_parent foo/integ wip/a || fail "foo/integ parent should be wip/a"
if exists local/integration; then fail "default bookmark should NOT be used when overridden"; fi

"$SCRIPT" clear >/dev/null 2>&1
assert_eq "$(cid mybase)" "$(cid 'foo/integ-')" "clear seats the custom bookmark on the custom base"

cd / && rm -rf "$repo"; echo "ok: custom"
