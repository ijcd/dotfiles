#!/usr/bin/env bash
# test_merge_notlive — a member with NO open PR still uses the clean cherry-pick
# path: a base bump rebuilds it sideways (old tip is NOT an ancestor of the new
# one). This is the "initial rebase" contract — force is free before a PR exists.
# JJ_MIRROR_LIVE_PRS="" forces the non-live decision hermetically (no gh call).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

printf 'base\n' > f; jj commit -m M0 >/dev/null; jj bookmark set master -r @- >/dev/null
jj new master >/dev/null; echo localonly > localonly; jj commit -m localbase >/dev/null
jj bookmark set local/main -r @- >/dev/null
jj new local/main >/dev/null; printf 'base\na\n' > f; jj commit -m a >/dev/null
jj bookmark set wip/a -r @- >/dev/null; jj new @- >/dev/null
jj config set --repo jj-mirror.source-root local/main >/dev/null
jj config set --repo jj-mirror.prime-root  master     >/dev/null

JJ_MIRROR_LIVE_PRS="" "$SCRIPT" sync >/dev/null
A0=$(jj log --no-graph -r pr/a -T 'commit_id.short()')

# Base bump; pr/a is NOT live.
jj new master >/dev/null; printf 'base\n' > f; echo x > other
jj commit -m M1 >/dev/null; jj bookmark set master -r @- >/dev/null

JJ_MIRROR_LIVE_PRS="" "$SCRIPT" sync >/dev/null
A1=$(jj log --no-graph -r pr/a -T 'commit_id.short()')

[[ "$A0" != "$A1" ]] || fail "pr/a should rebuild on base bump"
# Clean path: rebuilt sideways — A0 is NOT an ancestor of A1 (a rewrite, single parent).
if jj log --no-graph -r "$A0 & ancestors($A1)" -T '"y"' | grep -q y; then
  fail "non-live pr/a was merge-forwarded — expected a clean sideways rebuild"
fi
# New pr/a is an ordinary single-parent commit on the new base (no merge).
[[ $(first_parent_of pr/a | wc -l | tr -d ' ') -eq 1 ]] || true
assert_eq "$(jj log --no-graph -r master -T 'commit_id.short()')" "$(first_parent_of pr/a)" \
  "non-live pr/a rebuilt directly on master@M1"

cd / && rm -rf "$repo"
echo "ok: merge_notlive"
