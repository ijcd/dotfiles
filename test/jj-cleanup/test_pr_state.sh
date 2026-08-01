#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stub_dir
repo="$(mkrepo)"; cd "$repo"

export JJ_CLEANUP_REPO="owner/repo"   # gh_repo short-circuits (fixture has no colocated git/origin)

# gh stub: `gh pr list --json …` prints a JSON array ([] = no PR). Maps via $FAKE.
stub_cmd gh '
case "$FAKE" in
  merged) echo "[{\"state\":\"MERGED\",\"mergedAt\":\"2026-07-20T00:00:00Z\"}]";;
  open)   echo "[{\"state\":\"OPEN\",\"mergedAt\":null}]";;
  none)   echo "[]";;
esac'

# FAKE must reach the gh stub (a child process), so export it via the SCRIPT call —
# a var prefix on the assert_eq *function* isn't in scope during arg expansion.
assert_eq MERGED "$(FAKE=merged "$SCRIPT" __test_pr_state feat)" "merged PR"
assert_eq OPEN   "$(FAKE=open   "$SCRIPT" __test_pr_state feat)" "open PR"
assert_eq NONE   "$(FAKE=none   "$SCRIPT" __test_pr_state feat)" "no PR"

cd / && rm -rf "$repo"; echo "ok: pr_state"
