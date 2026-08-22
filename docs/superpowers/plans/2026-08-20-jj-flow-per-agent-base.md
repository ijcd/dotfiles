# jj-flow per-agent base — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline) or
> superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Each agent (jj workspace) gets its own private base `local/main-<workspace>`,
so catch-up + mirror operate on that agent's stream only — no more collisions on a
shared `local/main`.

**Architecture:** `flow_load_config` derives `FLOW_BASE` from the current workspace
(`local/main-<W>` if it exists, else `local/main`). That one value already drives
catch-up's rebase; it's additionally threaded into mirror's source-root so PRs
base-strip against the agent's base. New `jj-flow base fork|list` verbs mint/show
per-agent bases. No shared mutable state; borrow deferred.

**Tech Stack:** Bash 4+, jj 0.43, existing `jjflow-*.sh` modules + scratch-repo suites.

## Global Constraints

- Current workspace name: `cur=$(jj workspace root)`, matched against
  `jj workspace list -T 'name ++ "\t" ++ root ++ "\n"'` root column → name. (jj 0.43
  has no current-marker in `workspace list`.)
- `jj config --repo` is repo-shared across workspaces — NEVER use it for per-agent
  values. Per-agent = workspace-derived or env-passed.
- `FLOW_BASE` fallback order: `local/main-<W>` → explicit `[jj-flow] base` → `local/main`.
- Mirror source-root hand-off via env (`JJ_MIRROR_SOURCE_ROOT`), NOT by mutating repo config.
- Backward compat: no `local/main-<W>` and no override → behaves exactly as today.
- Bash 4+; modules stay sourced (no new exec-delegation); tests green per task.
- Do not commit/push; work under `dot_local/bin` + `test/`.

---

### Task 1: workspace-derived `FLOW_BASE`

**Files:** Modify `dot_local/bin/jjflow-lib.sh`; Test `test/jj-flow/test_ws_base.sh`.

**Interfaces:**
- Produces: `flow_current_workspace` → current workspace name (empty if single/none);
  `flow_load_config` sets `FLOW_BASE` per the fallback order; `FLOW_WS` = current ws name.

- [ ] **Step 1: failing test** — in a 2-workspace repo with `local/main-alice`, from
  the alice workspace `FLOW_BASE` resolves to `local/main-alice`; with no per-agent
  bookmark it falls back to `local/main`.

```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"; source "$BIN/jjflow-lib.sh"
repo="$(mkrepo)"; cd "$repo"
printf 'x\n'>f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj new master >/dev/null 2>&1; echo p>p; jj commit -m recipe >/dev/null 2>&1; jj bookmark set local/main -r @- >/dev/null 2>&1
ws="$repo-alice"; jj workspace add --name alice "$ws" >/dev/null 2>&1
jj bookmark set local/main-alice -r local/main >/dev/null 2>&1
( cd "$ws" && source "$BIN/jjflow-lib.sh" && flow_load_config && echo "$FLOW_BASE" ) | grep -qx 'local/main-alice' || fail "alice base not derived"
# fall back when no per-agent bookmark: default workspace, delete the alice bookmark path
( cd "$repo" && source "$BIN/jjflow-lib.sh" && flow_load_config && echo "$FLOW_BASE" ) | grep -qx 'local/main' || fail "fallback to local/main"
cd / && rm -rf "$repo" "$ws"; echo ok
```

- [ ] **Step 2: run, verify FAIL.**
- [ ] **Step 3: implement** in `jjflow-lib.sh`:

```bash
flow_current_workspace() {
  local cur n r; cur=$(jj workspace root 2>/dev/null) || return 0
  while IFS=$'\t' read -r n r; do [[ "$r" == "$cur" ]] && { printf '%s' "$n"; return 0; }; done \
    < <(jj workspace list -T 'name ++ "\t" ++ root ++ "\n"' 2>/dev/null)
}
```
In `flow_load_config`, after loading the plain `base`, override with the per-agent one:
```bash
FLOW_WS=$(flow_current_workspace)
if [[ -n "$FLOW_WS" ]] && jj log --no-graph -r "local/main-$FLOW_WS" -T '""' >/dev/null 2>&1; then
  FLOW_BASE="local/main-$FLOW_WS"
fi   # else keep the [jj-flow] base / local/main default already set
```

- [ ] **Step 4: run, verify PASS.**
- [ ] **Step 5: commit** (if asked).

---

### Task 2: `jj-flow base fork` + `base list`

**Files:** Create `dot_local/bin/jjflow-base.sh`; Modify `executable_jj-flow` (verb + `_flow_mod base`); Test `test/jj-flow/test_base.sh`.

**Interfaces:**
- Produces: `base_main fork` mints `local/main-<W>` = duplicate `trunk()..local/main`
  (the canonical recipe) onto trunk, idempotent; `base_main list` prints each
  `local/main-*` with drift.

- [ ] **Step 1: failing test** — `jj-flow base fork` in the alice workspace creates
  `local/main-alice` carrying the recipe files on master; second fork is a no-op;
  `base list` shows it.
- [ ] **Step 2: run, verify FAIL.**
- [ ] **Step 3: implement** `jjflow-base.sh` (`base_usage`, `base_fork`, `base_list`,
  `base_main`); lazy-source in jj-flow: `base) shift; _flow_mod base; base_main "$@"`.
  `base_fork`: resolve `FLOW_WS`; if `local/main-$FLOW_WS` exists and is on trunk →
  no-op; else `jj duplicate "trunk()..local/main" --destination trunk()` and bookmark
  the folded tip `local/main-$FLOW_WS` (reuse mirror's squash-fold pattern for a
  multi-commit recipe).
- [ ] **Step 4: run, verify PASS.**
- [ ] **Step 5: commit** (if asked).

---

### Task 3: catch-up isolation (per-agent)

**Files:** Modify `dot_local/bin/jjflow-catchup.sh` (already reads `FLOW_BASE`); Test `test/jj-catch-up/test_isolation.sh`.

**Interfaces:** Consumes Task 1's workspace-derived `FLOW_BASE`. No new surface — the
existing revsets (`catchup_private_root`/`catchup_mine`) already key off `FLOW_BASE`,
so once it's per-agent, catch-up is per-agent.

- [ ] **Step 1: failing test — the core isolation guarantee.** Two agents (alice, bob),
  each with `local/main-<a>` + `wip/<a>-x`. Advance master. Run catch-up **from the
  alice workspace**. Assert: `local/main-alice` + `wip/alice-x` rebased onto new
  master; `local/main-bob` + `wip/bob-x` **unchanged** (same commit ids).

```bash
# ... build both agents' bases+wip off master, advance master ...
BOB_BASE0=$(cid local/main-bob); BOB_WIP0=$(cid wip/bob-x)
( cd "$alice_ws" && JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" >/dev/null 2>&1 )
is_ancestor "$(cid master)" "$(cid local/main-alice)" || fail "alice base not caught up"
assert_eq "$BOB_BASE0" "$(cid local/main-bob)" "bob base untouched"
assert_eq "$BOB_WIP0"  "$(cid wip/bob-x)"      "bob wip untouched"
```

- [ ] **Step 2: run, verify FAIL** (today catch-up would use shared `local/main`).
- [ ] **Step 3: implement** — mostly falls out of Task 1; ensure `catchup_snapshot`
  and `refresh_main` don't over-reach to other agents' workspaces (they iterate all
  workspaces but only *this* agent's base moved, so others no-op — verify).
- [ ] **Step 4: run, verify PASS.**
- [ ] **Step 5: no-op test** — re-run catch-up from alice with base already current →
  reports no-op, `local/main-alice` unchanged. Commit (if asked).

---

### Task 4: mirror base-strips against the agent's base

**Files:** Modify `dot_local/bin/jjflow-mirror.sh` (source-root env override); Modify `executable_jj-flow` (set env for mirror/push from `FLOW_BASE`); Test `test/jj-mirror/test_source_root_env.sh`.

**Interfaces:** jj-flow exports `JJ_MIRROR_SOURCE_ROOT=$FLOW_BASE` before `mirror_main`;
mirror's `SOURCE_ROOT` honors that env over config (no repo-config mutation).

- [ ] **Step 1: failing test** — with `JJ_MIRROR_SOURCE_ROOT=local/main-alice`, a sync
  base-strips the PR against alice's base so `ijcd/<x>` contains only the feature
  commit(s), not alice's recipe.
- [ ] **Step 2: run, verify FAIL.**
- [ ] **Step 3: implement** — in `jjflow-mirror.sh` `load_config`, seed
  `SOURCE_ROOT="${JJ_MIRROR_SOURCE_ROOT:-<existing default/coalesce>}"`; in jj-flow's
  `mirror`/`push` verbs, `flow_load_config` then `JJ_MIRROR_SOURCE_ROOT="$FLOW_BASE" mirror_main …`.
- [ ] **Step 4: run, verify PASS** (+ existing 42 mirror tests still green — the env is
  unset there, so default behavior unchanged).
- [ ] **Step 5: commit** (if asked).

---

### Task 5: status by per-agent base + orphan-cull scoping

**Files:** Modify `executable_jj-flow` (`status_graph`/`status_main` grouping); Modify `dot_local/bin/jjflow-mirror.sh` (cull scope); Test `test/jj-flow/test_multibase_status.sh`, `test/jj-mirror/test_cull_scope.sh`.

**Interfaces:** status groups threads under their base; mirror's repo-wide orphan cull
is scoped so agent A's sync never culls agent B's `ijcd/*`.

- [ ] **Step 1: failing test (cull scope)** — two agents' `ijcd/*` present; a sync under
  `JJ_MIRROR_SOURCE_ROOT=local/main-alice` must NOT cull `ijcd/bob-*` (whose source is
  under bob's base).
- [ ] **Step 2: run, verify FAIL** (today's cull is repo-wide over all prime bookmarks).
- [ ] **Step 3: implement** — scope the cull to prime bookmarks whose thread derives
  from the current `SOURCE_ROOT`; leave others alone. (Simplest safe v1: only cull a
  prime whose suffix maps to a source bookmark absent *under the current base*, not
  repo-wide.)
- [ ] **Step 4: run, verify PASS** (+ existing orphan-cull test still green in single-base mode).
- [ ] **Step 5: status grouping** — `jj-flow status --graph` groups rows under each
  `local/main-*`, current agent highlighted. Full sweep green. Commit (if asked).

## Self-review

- Coverage: spec §crux (workspace-derived base) → Task 1; §verbs → Task 2 (fork/list),
  Task 5 (status); catch-up isolation → Task 3; mirror source-root hand-off (open q2) →
  Task 4; orphan-cull scoping (open q3) → Task 5. Open q1 (ws-name mechanism) resolved
  in Global Constraints.
- Placeholder scan: Tasks 2–5 steps compress some test bodies to prose + key asserts —
  expand to full scripts at execution time (Task 1/3 show the shape).
- Types: `flow_current_workspace`, `FLOW_BASE`, `FLOW_WS`, `base_main`, `JJ_MIRROR_SOURCE_ROOT`
  consistent across tasks.
- Sequence: 1 (base derivation) → 2 (fork, so bases exist) → 3 (catch-up isolation) →
  4 (mirror) → 5 (status + cull). Each independently testable + shippable.
