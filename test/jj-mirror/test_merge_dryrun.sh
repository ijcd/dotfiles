#!/usr/bin/env bash
# test_merge_dryrun — the read-only verdict engine predicts the merge-forward
# without mutating: a stale member that backs a live PR reads "would merge-forward",
# and the same member with no live PR reads "would rebuild". This is the lockstep
# that keeps `sync --dry-run` and `status` honest about what sync will do.
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

"$SCRIPT" sync >/dev/null
# Base bump — pr/a is now stale (base moved).
jj new master >/dev/null; printf 'base\n' > f; echo x > other
jj commit -m M1 >/dev/null; jj bookmark set master -r @- >/dev/null

# Live → merge-forward predicted.
out=$(JJ_MIRROR_LIVE_PRS="pr/a" "$SCRIPT" sync --dry-run 2>&1)
grep -q 'would merge-forward pr/a' <<<"$out" \
  || fail "dry-run did not predict merge-forward for live pr/a; got: $out"
# Dry-run must not have mutated: pr/a still on its pre-sync commit.
[[ $(first_parent_of pr/a) == "$(jj log --no-graph -r 'master-' -T 'commit_id.short()')" ]] \
  || fail "dry-run mutated pr/a (base changed)"

# Not live → clean rebuild predicted.
out=$(JJ_MIRROR_LIVE_PRS="" "$SCRIPT" sync --dry-run 2>&1)
grep -q 'would rebuild pr/a' <<<"$out" \
  || fail "dry-run did not predict a clean rebuild for non-live pr/a; got: $out"

cd / && rm -rf "$repo"
echo "ok: merge_dryrun"
