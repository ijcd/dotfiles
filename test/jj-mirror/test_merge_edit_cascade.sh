#!/usr/bin/env bash
# test_merge_edit_cascade — editing a middle commit of a LIVE stack must advance
# that PR and cascade to the ones above it as append-only merge-forwards (each
# old tip an ancestor of its new tip = fast-forward), while the untouched bottom
# PR stays put (no commit, no push). Also proves jj-vine base derivation: each
# member's first parent tracks its downstack neighbor across the cascade.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

printf 'base\n' > f; jj commit -m M0 >/dev/null; jj bookmark set master -r @- >/dev/null
jj new master >/dev/null; echo localonly > localonly; jj commit -m localbase >/dev/null
jj bookmark set local/main -r @- >/dev/null
# Stack of three, each touching a distinct file (portable diffs).
jj new local/main >/dev/null; echo A > fileA; jj commit -m a >/dev/null; jj bookmark set wip/a -r @- >/dev/null
echo B > fileB; jj commit -m b >/dev/null; jj bookmark set wip/b -r @- >/dev/null
echo C > fileC; jj commit -m c >/dev/null; jj bookmark set wip/c -r @- >/dev/null
jj new @- >/dev/null
jj config set --repo jj-mirror.source-root local/main >/dev/null
jj config set --repo jj-mirror.prime-root  master     >/dev/null

"$SCRIPT" sync >/dev/null
A0=$(jj log --no-graph -r pr/a -T 'commit_id.short()')
B0=$(jj log --no-graph -r pr/b -T 'commit_id.short()')
C0=$(jj log --no-graph -r pr/c -T 'commit_id.short()')

# Edit the MIDDLE source commit (wip/b): change fileB. jj auto-rebases wip/c.
jj edit wip/b >/dev/null; echo B2 > fileB; jj new wip/c >/dev/null

# All three PRs are live.
JJ_MIRROR_LIVE_PRS="pr/a pr/b pr/c" "$SCRIPT" sync >/dev/null
A1=$(jj log --no-graph -r pr/a -T 'commit_id.short()')
B1=$(jj log --no-graph -r pr/b -T 'commit_id.short()')
C1=$(jj log --no-graph -r pr/c -T 'commit_id.short()')

# Bottom PR untouched — no rewrite, no new commit.
assert_eq "$A0" "$A1" "pr/a unchanged (no-op)"
# Middle PR advanced, fast-forward (old tip ancestor of new).
[[ "$B0" != "$B1" ]] || fail "pr/b did not advance after edit"
jj log --no-graph -r "$B0 & ancestors($B1)" -T '"y"' | grep -q y || fail "pr/b moved sideways (not ff)"
# Top PR cascaded, also fast-forward.
[[ "$C0" != "$C1" ]] || fail "pr/c did not cascade after mid-stack edit"
jj log --no-graph -r "$C0 & ancestors($C1)" -T '"y"' | grep -q y || fail "pr/c moved sideways (not ff)"

# jj-vine base derivation intact across the cascade.
assert_eq "$A1" "$(first_parent_of pr/b)" "pr/b base = pr/a"
assert_eq "$B1" "$(first_parent_of pr/c)" "pr/c base = new pr/b"

# Content correct at the tip: fileA, edited fileB (B2), fileC all present.
assert_eq "B2" "$(jj file show -r pr/c fileB)" "edited content reached pr/c"
jj file list -r pr/c | grep -qx fileA || fail "pr/c missing fileA"
jj file list -r pr/c | grep -qx fileC || fail "pr/c missing fileC"

cd / && rm -rf "$repo"
echo "ok: merge_edit_cascade"
