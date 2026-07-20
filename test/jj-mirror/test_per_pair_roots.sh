#!/usr/bin/env bash
# test_per_pair_roots — different mirror pairs can target different roots.
# feat-a uses the global prime-root (trunk); feat-b overrides its prime-root to a
# separate 'rel' base via jj-mirror.roots.feat-b.prime.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"

# local/main base (the default source root).
echo base > base.txt && jj commit -m "local base" 2>/dev/null
jj bookmark set local/main -r @- 2>/dev/null

# A separate release base 'rel' off trunk(), sibling to local/main.
jj new 'trunk()' 2>/dev/null
echo rel > rel.txt && jj commit -m "rel base" 2>/dev/null
jj bookmark set rel -r @- 2>/dev/null

# Two source threads off local/main.
jj new local/main 2>/dev/null
echo a > a.txt && jj commit -m "feat-a" 2>/dev/null; jj bookmark set wip/feat-a -r @- 2>/dev/null
jj new local/main 2>/dev/null
echo b > b.txt && jj commit -m "feat-b" 2>/dev/null; jj bookmark set wip/feat-b -r @- 2>/dev/null

# feat-b overrides its prime root to 'rel'; feat-a keeps the global default (trunk).
jj config set --repo jj-mirror.roots.feat-b.prime "rel" 2>/dev/null

"$SCRIPT" sync

trunk=$(jj log --no-graph -r "trunk()"     -T 'commit_id.short() ++ "\n"')
rel=$(jj log --no-graph   -r "rel"         -T 'commit_id.short() ++ "\n"')
pa=$(jj log --no-graph    -r "pr/feat-a-"  -T 'commit_id.short() ++ "\n"')
pb=$(jj log --no-graph    -r "pr/feat-b-"  -T 'commit_id.short() ++ "\n"')

assert_eq "$trunk" "$pa" "pr/feat-a on global prime-root (trunk)"
assert_eq "$rel"   "$pb" "pr/feat-b on its per-pair prime-root (rel)"

# config should surface the override.
"$SCRIPT" config | grep -q 'feat-b\.prime' || fail "config did not list the per-pair override"

# graph should render both threads and mark feat-b's prime root as an override.
g="$("$SCRIPT" status --graph)"
[[ "$g" == *"wip/feat-a"* && "$g" == *"wip/feat-b"* ]] || fail "graph missing threads: $g"
[[ "$g" == *"rel *"* ]] || fail "graph should mark feat-b's prime root (rel) as an override: $g"

cd / && rm -rf "$repo"
echo "ok: per_pair_roots"
