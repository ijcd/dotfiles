#!/usr/bin/env bash
# test_sync_orphan — deleting a source bookmark culls its prime counterpart.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
echo a1 > f && jj commit -m "a1" >/dev/null 2>&1; jj bookmark set wip/a1 -r @- >/dev/null 2>&1
echo a2 > f && jj commit -m "a2" >/dev/null 2>&1; jj bookmark set wip/a2 -r @- >/dev/null 2>&1
echo a3 > f && jj commit -m "a3" >/dev/null 2>&1; jj bookmark set wip/a3 -r @- >/dev/null 2>&1
"$SCRIPT" sync

# Delete wip/a2 bookmark AND its underlying commit (squash into a3 so a3's diff still applies)
jj squash --from "wip/a2" --to "wip/a3" -u >/dev/null 2>&1
jj bookmark delete wip/a2 >/dev/null 2>&1

"$SCRIPT" sync

# pr/a2 should no longer exist
if jj log --no-graph -r "pr/a2" -T '""' >/dev/null 2>&1; then
  fail "pr/a2 should have been culled"
fi
# pr/a1 and pr/a3 should still exist
for name in pr/a1 pr/a3; do
  jj log --no-graph -r "$name" -T '""' >/dev/null 2>&1 \
    || fail "$name bookmark missing after orphan cull"
done

cd / && rm -rf "$repo"
echo "ok: sync_orphan"
