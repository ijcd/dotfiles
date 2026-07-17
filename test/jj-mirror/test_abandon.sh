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

# Idempotent — second call is no-op, exit 0
"$SCRIPT" abandon a2 >/dev/null 2>&1 || fail "second abandon should be idempotent"

cd / && rm -rf "$repo"
echo "ok: abandon"
