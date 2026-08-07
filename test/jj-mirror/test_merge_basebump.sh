#!/usr/bin/env bash
# test_merge_basebump — a LIVE single PR whose prime root advances must
# merge-forward: the dest bookmark moves to a DESCENDANT of its old tip (push
# fast-forwards, review comments survive) instead of being rebuilt sideways
# (force-push). Liveness is injected via JJ_MIRROR_LIVE_PRS (no network in tests).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# master(M0) ← local/main(localonly) ← wip/a(+a on f)
printf 'base\n' > f; jj commit -m M0 >/dev/null; jj bookmark set master -r @- >/dev/null
jj new master >/dev/null; echo localonly > localonly; jj commit -m localbase >/dev/null
jj bookmark set local/main -r @- >/dev/null
jj new local/main >/dev/null; printf 'base\na\n' > f; jj commit -m a >/dev/null
jj bookmark set wip/a -r @- >/dev/null; jj new @- >/dev/null
jj config set --repo jj-mirror.source-root local/main >/dev/null
jj config set --repo jj-mirror.prime-root  master     >/dev/null

# Initial sync — clean cherry-pick creates pr/a on master (no PR yet).
"$SCRIPT" sync >/dev/null
A0=$(jj log --no-graph -r pr/a -T 'commit_id.short()')
[[ -n "$A0" ]] || fail "pr/a not created by initial sync"
# Sanity: pr/a's first parent is the prime root (master@M0), diff is +a.
assert_eq "$(jj log --no-graph -r master -T 'commit_id.short()')" "$(first_parent_of pr/a)" "pr/a on master initially"

# master advances M0 → M1 (adds an unrelated file); pr/a is now LIVE.
jj new master >/dev/null; printf 'base\n' > f; echo x > other
jj commit -m M1 >/dev/null; jj bookmark set master -r @- >/dev/null

JJ_MIRROR_LIVE_PRS="pr/a" "$SCRIPT" sync >/dev/null
A1=$(jj log --no-graph -r pr/a -T 'commit_id.short()')

[[ "$A0" != "$A1" ]] || fail "pr/a did not advance on base bump"
# Append-only: A0 is an ancestor of A1 → fast-forward, no force-push.
jj log --no-graph -r "$A0 & ancestors($A1)" -T '"y"' | grep -q y \
  || fail "pr/a moved SIDEWAYS (A0 not an ancestor of A1) — would force-push"
# jj-vine base derivation: first parent of the merge-forwarded pr/a is master@M1.
assert_eq "$(jj log --no-graph -r master -T 'commit_id.short()')" "$(first_parent_of pr/a)" \
  "pr/a base = master@M1 after merge-forward"
# Content still correct: +a present, and M1's 'other' included.
assert_eq $'base\na' "$(jj file show -r pr/a f)" "pr/a still carries +a"
jj file list -r pr/a | grep -qx other || fail "pr/a missing new-base content"

cd / && rm -rf "$repo"
echo "ok: merge_basebump"
