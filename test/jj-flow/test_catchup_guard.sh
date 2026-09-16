#!/usr/bin/env bash
# test_catchup_guard — catchup REFUSES when a per-agent workspace fell back to the
# shared local/main base while other agents hold per-agent bases (a fleet). Refusing
# is what stops the shared-stack sweep. A repo with NO per-agent bases (single-agent)
# is unaffected.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
mk_layers   # master(trunk) <- local/main <- @

# a fleet peer HAS a per-agent base; 40 legacy wip/* hang off shared local/main
jj new local/main >/dev/null 2>&1; echo p > peer; jj commit -m peerbase >/dev/null 2>&1
jj bookmark set local/main-peer -r @- >/dev/null 2>&1
for i in $(seq 1 40); do
  jj new local/main >/dev/null 2>&1; echo "$i" > "f$i"; jj commit -m "w$i" >/dev/null 2>&1
  jj bookmark set "wip/stale-$i" -r @- >/dev/null 2>&1
done

# I am the default workspace with NO local/main-<W>; FLOW_BASE falls back to shared.
pre=$(jj op log --limit 1 --no-graph -T 'id' 2>/dev/null | head -n1)
out=$(JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" catchup 2>&1) && fail "catchup did not refuse the shared-base fallback"
assert_contains "$out" "base fork" "guidance names the remedy"
post=$(jj op log --limit 1 --no-graph -T 'id' 2>/dev/null | head -n1)
assert_eq "$pre" "$post" "nothing was rewritten on refusal"

cd / && rm -rf "$repo"

# Regression — single-agent repo (no per-agent base anywhere) still catches up.
repo2="$(mkrepo)"; cd "$repo2"
mk_layers
jj new local/main >/dev/null 2>&1; echo x > fx; jj commit -m wx >/dev/null 2>&1
jj bookmark set wip/only -r @- >/dev/null 2>&1
JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" catchup >/dev/null 2>&1 \
  || fail "single-agent catchup regressed"
cd / && rm -rf "$repo2"

# Regression — an explicitly-configured isolation base (test/main) must NOT be refused,
# even with per-agent peers present. The guard refuses ONLY the bare shared local/main;
# test/main is an intentional opt-in (jj-flow.base), not a silent fallback.
repo3="$(mkrepo)"; cd "$repo3"
mk_layers
jj new local/main >/dev/null 2>&1; echo t > ft; jj commit -m tbase >/dev/null 2>&1; jj bookmark set test/main -r @- >/dev/null 2>&1
jj new local/main >/dev/null 2>&1; echo p > fp; jj commit -m peer  >/dev/null 2>&1; jj bookmark set local/main-peer -r @- >/dev/null 2>&1
( cd "$repo3" && FLOW_BASE=test/main FLOW_WS=x \
    bash -c 'source "'"$BIN"'/jjflow-lib.sh"; source "'"$BIN"'/jjflow-catchup.sh"; catchup_guard_base' ) \
  || fail "guard wrongly refused an explicit test/main isolation base"
cd / && rm -rf "$repo3"

echo "ok: catchup_guard"
