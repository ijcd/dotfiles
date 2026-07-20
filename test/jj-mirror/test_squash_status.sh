#!/usr/bin/env bash
# test_squash_status — squash no-op detection + squash status must be diff-format
# independent. Runs with an ISOLATED jj config (no ui.diff-formatter) so a personal
# `:git` default can't mask a mismatch between diff_hash and range_diff_hash. Also
# exercises a 3-commit squash, pinning the duplicate-range root/tip ordering.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# Isolate global jj config; identity still comes from mkrepo's --repo config.
tmpcfg="$(mktemp -d)/jj.toml"; : > "$tmpcfg"; export JJ_CONFIG="$tmpcfg"

repo="$(mkrepo)"; cd "$repo"
echo base > base.txt && jj commit -m base 2>/dev/null; jj bookmark set local/main -r @- 2>/dev/null
jj new local/main 2>/dev/null
echo a > a.txt && jj commit -m c1 2>/dev/null
echo b > b.txt && jj commit -m c2 2>/dev/null
echo c > c.txt && jj commit -m c3 2>/dev/null
jj bookmark set wip/feat -r @- 2>/dev/null

"$SCRIPT" add 'wip/*' 'ijcd/*' --squash >/dev/null 2>&1
"$SCRIPT" sync

# One cumulative commit carrying all three files.
n=$(jj log --no-graph -r "trunk()..ijcd/feat" -T '"x\n"' | grep -c x)
assert_eq "1" "$n" "3-commit squash should collapse to one dest commit"
for f in a.txt b.txt c.txt; do
  jj file list -r "ijcd/feat" 2>/dev/null | grep -qx "$f" || fail "ijcd/feat missing $f"
done

# Status must read ok right after sync (would be 'stale' if the formats disagree).
out="$("$SCRIPT" status)"
[[ "$out" == *"ijcd/feat"*"ok"* ]] || fail "squash status should be ok after sync: $out"

# Re-sync must be a no-op (same commit id) — the squash no-op check must fire.
before=$(jj log --no-graph -r "ijcd/feat" -T 'commit_id.short()' | head -n1)
"$SCRIPT" sync >/dev/null 2>&1
after=$(jj log --no-graph -r "ijcd/feat" -T 'commit_id.short()' | head -n1)
assert_eq "$before" "$after" "squash re-sync must be a no-op (format-independent)"

cd / && rm -rf "$repo"; echo "ok: squash_status"
