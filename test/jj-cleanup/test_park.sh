#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 3)"
c1="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 1p)"
c2="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 2p)"
jj bookmark create ijcd/feat -r "$c2" 2>/dev/null   # merged = feat1,feat2; lost = feat3

"$SCRIPT" __test_do_park feat todo/keep-feat3

exists todo/keep-feat3 || fail "todo bookmark created"
# todo/keep-feat3 sits directly on local/main (merged middle dropped): its only
# thread commit over base is feat3 → count == 1.
assert_eq 1 "$(countrev "local/main..todo/keep-feat3")" "parked tail is 1 commit on base"
# base intact
exists local/main || fail "local/main survived"

cd / && rm -rf "$repo" "$wsA"; echo "ok: park"
