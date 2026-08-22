#!/usr/bin/env bash
# test_agent_status — status is per-agent aware: run from alice's workspace, the
# base line reflects local/main-alice (not the shared local/main). Cross-agent
# listing is `jj-flow base list`.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'x\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo r > personal; jj commit -m recipe >/dev/null 2>&1; jj bookmark set local/main -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo r > personal; jj commit -m ra >/dev/null 2>&1; jj bookmark set local/main-alice -r @- >/dev/null 2>&1
jj new local/main-alice >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/alice-x -r @- >/dev/null 2>&1
jj config set --repo jj-flow.trunk master >/dev/null 2>&1
ws="$repo-alice"; jj workspace add --name alice "$ws" >/dev/null 2>&1

out=$( cd "$ws" && jj config set --repo jj-flow.trunk master >/dev/null 2>&1; "$SCRIPT" status 2>&1 )
assert_contains "$out" 'local/main-alice' "status base line reflects the agent's own base"
assert_contains "$out" 'wip/alice-x'      "status shows the agent's wip"

# base list shows every base (cross-agent view)
out=$( cd "$ws" && "$SCRIPT" base list 2>&1 )
assert_contains "$out" 'local/main-alice' "base list shows alice"

cd / && rm -rf "$repo" "$ws"
echo "ok: agent_status"
