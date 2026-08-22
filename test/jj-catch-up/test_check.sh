#!/usr/bin/env bash
# test_check — `catchup -c` validates workspace paths: exit 0 when all resolve,
# non-zero (and named) when a workspace's recorded path is gone.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'x\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj config set --repo jj-flow.trunk master >/dev/null 2>&1

# all paths resolve → exit 0
out=$("$SCRIPT" -c 2>&1); rc=$?
assert_eq 0 "$rc" "check passes when paths resolve"
assert_contains "$out" 'all workspace paths resolve' "check reports clean"

# add a second workspace, then delete its dir → broken path
wsdir="$(mktemp -d "${TMPDIR:-/tmp}/catchup-ws2.XXXXXX")"; rm -rf "$wsdir"
jj workspace add --name w2 "$wsdir" >/dev/null 2>&1
rm -rf "$wsdir"
out=$("$SCRIPT" -c 2>&1); rc=$?
[[ "$rc" -ne 0 ]] || fail "check should exit non-zero with a broken workspace path"
assert_contains "$out" 'w2' "broken workspace named in the warning"

cd / && rm -rf "$repo"
echo "ok: check"
