#!/usr/bin/env bash
# test_abandon — removes both source and prime bookmarks and their commits.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
echo a1 > f && jj commit -m "a1"; jj bookmark set wip/a1 -r @-
echo a2 > f && jj commit -m "a2"; jj bookmark set wip/a2 -r @-
"$SCRIPT" sync >/dev/null 2>&1

wip_a2_cid=$(jj log --no-graph -r "wip/a2" -T 'commit_id.short() ++ "\n"')
pr_a2_cid=$(jj log  --no-graph -r "pr/a2"  -T 'commit_id.short() ++ "\n"')

"$SCRIPT" abandon a2 >/dev/null 2>&1

if jj bookmark list -T 'name ++ "\n"' | grep -qE '^(wip|pr)/a2$'; then
  fail "wip/a2 or pr/a2 still exists after abandon"
fi

# Commits should be dropped from the visible DAG. `jj log -r <cid>` in jj still
# resolves abandoned commits by hash (they linger in the store), so we can't use
# that as the check — instead, verify the commit id is not reachable from @.
if jj log --no-graph -r "ancestors(@) & $wip_a2_cid" -T 'commit_id.short() ++ "\n"' 2>/dev/null | grep -q .; then
  fail "wip/a2 commit $wip_a2_cid still an ancestor of @ after abandon"
fi
if jj log --no-graph -r "ancestors(@) & $pr_a2_cid" -T 'commit_id.short() ++ "\n"' 2>/dev/null | grep -q .; then
  fail "pr/a2 commit $pr_a2_cid still an ancestor of @ after abandon"
fi

# Idempotent — second call is no-op, exit 0
"$SCRIPT" abandon a2 >/dev/null 2>&1 || fail "second abandon should be idempotent"

cd / && rm -rf "$repo"
echo "ok: abandon"
