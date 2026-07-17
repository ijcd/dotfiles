#!/usr/bin/env bash
# test_validation — the spec's shape invariants for source threads are enforced:
#   - two source bookmarks on the same commit  → exit 2, ambiguous pairing
#   - a merge commit anywhere in trunk()..leaf  → exit 2, non-linear thread
# Both are Failure-modes-table commitments in the design spec.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# ─── same-commit ambiguous pairing ────────────────────────────────────────────
repo="$(mkrepo)"
cd "$repo"

echo a1 > f && jj commit -m "a1" >/dev/null 2>&1
jj bookmark set wip/a -r @- >/dev/null 2>&1
jj bookmark set wip/b -r @- >/dev/null 2>&1   # SAME commit as wip/a — ambiguous

set +e
out="$("$SCRIPT" sync 2>&1)"
rc=$?
set -e

[[ $rc -eq 2 ]] || fail "same-commit sync should exit 2 (got $rc): $out"
[[ "$out" == *"ambiguous pairing"* ]] || fail "error must mention 'ambiguous pairing': $out"

# Same rejection at status_main.
set +e
out="$("$SCRIPT" status 2>&1)"
rc=$?
set -e
[[ $rc -eq 2 ]] || fail "same-commit status should exit 2 (got $rc): $out"

cd / && rm -rf "$repo"

# ─── non-linear thread (merge in trunk()..leaf) ───────────────────────────────
repo="$(mkrepo)"
cd "$repo"

# Two parallel commits off trunk, then a merge.
echo a > fa && jj commit -m "a" >/dev/null 2>&1
a_cid=$(jj log --no-graph -r @- -T 'commit_id.short() ++ "\n"')
jj new 'trunk()' -m "b" >/dev/null 2>&1
echo b > fb && jj describe -m "b" >/dev/null 2>&1
b_cid=$(jj log --no-graph -r @ -T 'commit_id.short() ++ "\n"')
# Merge commit takes both parents.
jj new "$a_cid" "$b_cid" -m "merge" >/dev/null 2>&1
jj bookmark set wip/merged -r @ >/dev/null 2>&1

set +e
out="$("$SCRIPT" sync 2>&1)"
rc=$?
set -e

[[ $rc -eq 2 ]] || fail "merge-in-thread sync should exit 2 (got $rc): $out"
[[ "$out" == *"non-linear"* ]] || fail "error must mention 'non-linear': $out"

cd / && rm -rf "$repo"

echo "ok: validation"
