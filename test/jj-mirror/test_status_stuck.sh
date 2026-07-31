#!/usr/bin/env bash
# test_status_stuck — status --graph must FLAG a thread whose staleness is a
# base divergence (a rebuild won't clear it), not render it as an ordinary
# ◐ stale that "sync would fix". The graph should name the diverging file and
# point at the fix.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
mk_divergent_thread

# Rebuild the prime (sync now exits non-zero on the stuck thread — ignore rc).
"$SCRIPT" sync >/dev/null 2>&1 || true

g="$("$SCRIPT" status --graph 2>&1)"

[[ "$g" == *"wip/x"* ]] || fail "graph missing thread wip/x: $g"
[[ "$g" == *"cfg"*   ]] || fail "graph should name the diverging file cfg: $g"
[[ "$g" == *"divergence"* || "$g" == *"jj-catch-up"* || "$g" == *"cannot"* ]] \
  || fail "graph should flag the base divergence (not just ◐ stale): $g"

cd / && rm -rf "$repo"
echo "ok: status_stuck"
