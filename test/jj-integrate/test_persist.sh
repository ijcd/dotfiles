#!/usr/bin/env bash
# test_persist — membership is stored in repo config and survives across separate
# script invocations (not derived from the merge's transient commit-parents).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase; mkwip wip/a; mkwip wip/b

"$SCRIPT" add wip/a >/dev/null 2>&1     # invocation 1
"$SCRIPT" add wip/b >/dev/null 2>&1     # invocation 2 — must remember wip/a

m="$(jj config get jj-integrate.members 2>/dev/null)"
[[ "$m" == *"wip/a"* && "$m" == *"wip/b"* ]] || fail "membership should persist across invocations: $m"
assert_eq "2" "$(nparents local/integration)" "both members merged after two separate adds"

cd / && rm -rf "$repo"; echo "ok: persist"
