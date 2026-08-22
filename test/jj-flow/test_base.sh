#!/usr/bin/env bash
# test_base — `jj-flow base fork` mints local/main-<W> from the canonical recipe on
# trunk (idempotent); `base list` shows it.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'x\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo recipe > personal; jj commit -m recipe >/dev/null 2>&1
jj bookmark set local/main -r @- >/dev/null 2>&1
jj config set --repo jj-flow.trunk master >/dev/null 2>&1
ws="$repo-alice"; jj workspace add --name alice "$ws" >/dev/null 2>&1

# fork in the alice workspace
( cd "$ws" && jj config set --repo jj-flow.trunk master >/dev/null 2>&1; "$SCRIPT" base fork >/dev/null 2>&1 )
jj log --no-graph -r 'local/main-alice' -T '""' >/dev/null 2>&1 || fail "local/main-alice not created"
# it carries the recipe file, on master (base-stripped: no local/main's own extra history beyond recipe)
jj file list -r 'local/main-alice' | grep -qx personal || fail "forked base missing the recipe file"
# first parent chain reaches master (recipe duplicated onto trunk)
jj log --no-graph -r 'local/main-alice & descendants(master)' -T '"y"' | grep -q y || fail "forked base not on master"

# idempotent: second fork is a no-op, bookmark unchanged
B0=$(jj log --no-graph -r 'local/main-alice' -T 'commit_id.short()')
( cd "$ws" && "$SCRIPT" base fork >/dev/null 2>&1 )
assert_eq "$B0" "$(jj log --no-graph -r 'local/main-alice' -T 'commit_id.short()')" "second fork is a no-op"

# base list shows it
out=$( cd "$ws" && "$SCRIPT" base list 2>&1 )
assert_contains "$out" 'local/main-alice' "base list shows the agent base"

cd / && rm -rf "$repo" "$ws"
echo "ok: base"
