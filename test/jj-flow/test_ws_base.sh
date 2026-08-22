#!/usr/bin/env bash
# test_ws_base — FLOW_BASE derives from the current workspace: local/main-<W> when
# that bookmark exists, else the [jj-flow] base / local/main fallback. This is what
# lets each agent (workspace) work off its own base without per-repo config.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'x\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo p > p; jj commit -m recipe >/dev/null 2>&1; jj bookmark set local/main -r @- >/dev/null 2>&1

ws="$repo-alice"; jj workspace add --name alice "$ws" >/dev/null 2>&1
jj bookmark set local/main-alice -r local/main >/dev/null 2>&1

# from the alice workspace → local/main-alice
out=$( cd "$ws" && source "$BIN/jjflow-lib.sh" && flow_load_config && printf '%s' "$FLOW_BASE" )
assert_eq "local/main-alice" "$out" "alice workspace derives its own base"

# from the default workspace (no local/main-default) → fallback local/main
out=$( cd "$repo" && source "$BIN/jjflow-lib.sh" && flow_load_config && printf '%s' "$FLOW_BASE" )
assert_eq "local/main" "$out" "no per-agent bookmark → fallback to local/main"

# flow_current_workspace names the current workspace
out=$( cd "$ws" && source "$BIN/jjflow-lib.sh" && flow_current_workspace )
assert_eq "alice" "$out" "flow_current_workspace names the current workspace"

cd / && rm -rf "$repo" "$ws"
echo "ok: ws_base"
