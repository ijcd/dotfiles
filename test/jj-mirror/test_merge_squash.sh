#!/usr/bin/env bash
# test_merge_squash — a LIVE single-commit (--squash) PR advances append-only when
# the cumulative diff changes: the dest moves to a DESCENDANT of its old tip
# (fast-forward) instead of being rebuilt sideways. Re-sync is then a no-op.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

# A real prime root (master) — a live PR always sits on a real branch, never the
# virtual root commit (which the git backend can't use as a merge parent).
printf 'trunk\n' > f && jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1
echo base > base.txt && jj commit -m "local base" >/dev/null 2>&1
jj bookmark set local/main -r @- >/dev/null 2>&1
jj new local/main >/dev/null 2>&1
echo a > a.txt && jj commit -m c1 >/dev/null 2>&1
echo b > b.txt && jj commit -m c2 >/dev/null 2>&1
jj bookmark set wip/feat -r @- >/dev/null 2>&1
jj new @- >/dev/null 2>&1

"$SCRIPT" add 'wip/*' 'ijcd/*' --squash >/dev/null 2>&1
jj config set --repo jj-mirror.source-root local/main >/dev/null 2>&1
jj config set --repo jj-mirror.prime-root  master     >/dev/null 2>&1
"$SCRIPT" sync >/dev/null 2>&1
F0=$(jj log --no-graph -r ijcd/feat -T 'commit_id.short()')
[[ -n "$F0" ]] || fail "ijcd/feat not created"

# Extend the source branch (cumulative diff now includes c.txt).
jj edit wip/feat >/dev/null 2>&1
echo c > c.txt && jj commit -m c3 >/dev/null 2>&1
jj bookmark set --allow-backwards wip/feat -r @- >/dev/null 2>&1
jj new @- >/dev/null 2>&1

# ijcd/feat is live → merge-forward.
JJ_MIRROR_LIVE_PRS="ijcd/feat" "$SCRIPT" sync >/dev/null 2>&1
F1=$(jj log --no-graph -r ijcd/feat -T 'commit_id.short()')

[[ "$F0" != "$F1" ]] || fail "ijcd/feat did not advance after cumulative change"
# Append-only: F0 is an ancestor of F1 (fast-forward, no force-push).
jj log --no-graph -r "$F0 & ancestors($F1)" -T '"y"' | grep -q y \
  || fail "ijcd/feat moved sideways (F0 not an ancestor of F1)"
# Cumulative content correct: a, b, c present; local base still stripped.
for f in a.txt b.txt c.txt; do
  jj file list -r ijcd/feat | grep -qx "$f" || fail "ijcd/feat missing $f"
done
jj file list -r ijcd/feat | grep -qx base.txt && fail "ijcd/feat leaked local base file"

# Re-sync is a no-op now that the cumulative diff matches on the prime root.
JJ_MIRROR_LIVE_PRS="ijcd/feat" "$SCRIPT" sync >/dev/null 2>&1
F2=$(jj log --no-graph -r ijcd/feat -T 'commit_id.short()')
assert_eq "$F1" "$F2" "squash merge-forward re-sync should be a no-op"

cd / && rm -rf "$repo"
echo "ok: merge_squash"
