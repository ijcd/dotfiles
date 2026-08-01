#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 3)"   # 3 commits on local/main: feat1,feat2,feat3

# Simulate a prime that captured only the first 2 (feat1,feat2): a 2-commit chain on trunk-ish.
base="$(cid local/main)"
c1="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 1p)"
c2="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 2p)"
jj bookmark create ijcd/feat -r "$c2" 2>/dev/null   # prime = 2 commits deep

# prime_count counts <base>..ijcd/feat (base=local/main) = c1+c2 = 2.
pc="$(countrev "local/main..ijcd/feat")"
assert_eq 2 "$pc" "prime holds 2 commits over base"

# lost_tail_root = 3rd thread commit (index 2) = feat3's id
root="$("$SCRIPT" __test_lost_tail_root feat)"
c3="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 3p)"
assert_eq "$c3" "$root" "lost tail root is feat3"

# Fully-merged case: prime captures all 3 → no lost tail.
jj bookmark set ijcd/feat -r "$(cid wip/feat)" 2>/dev/null
assert_eq "" "$("$SCRIPT" __test_lost_tail_root feat)" "nothing lost when prime == wip"

cd / && rm -rf "$repo" "$wsA"; echo "ok: lost"
