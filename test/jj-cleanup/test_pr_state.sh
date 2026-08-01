#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stub_dir
repo="$(mkrepo)"; cd "$repo"

# gh stub: reads branch from args, maps via $FAKE. "MERGED@time" | "OPEN" | exits 1 for none/error.
stub_cmd gh '
br="";
for a in "$@"; do case "$a" in ijcd/*) br="$a";; esac; done
case "$FAKE" in
  merged) echo "{\"state\":\"MERGED\",\"mergedAt\":\"2026-07-20T00:00:00Z\"}";;
  open)   echo "{\"state\":\"OPEN\",\"mergedAt\":null}";;
  none)   echo "no pull requests found" >&2; exit 1;;
esac'

# FAKE must reach the gh stub (a child process), so export it via the SCRIPT call —
# a var prefix on the assert_eq *function* isn't in scope during arg expansion.
assert_eq MERGED "$(FAKE=merged "$SCRIPT" __test_pr_state feat)" "merged PR"
assert_eq OPEN   "$(FAKE=open   "$SCRIPT" __test_pr_state feat)" "open PR"
assert_eq NONE   "$(FAKE=none   "$SCRIPT" __test_pr_state feat)" "no PR"

cd / && rm -rf "$repo"; echo "ok: pr_state"
