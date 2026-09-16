# jjf catchup — targeted scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `jjf catchup` restack only the current agent's stream (the 2–5 wip/* on its base), never every wip/* in the repo.

**Architecture:** Two-part fix. (1) A **base-resolution guard** — refuse catchup when a per-agent workspace has silently fallen back to the shared `local/main` base (the root cause of the 40+ sweep). (2) **Ownership-scoped restack** — enumerate the wip/* the current base owns (nearest-`local/main*`-base wins) and restack + conflict-check exactly that set, mirroring the per-agent scoping `d534ae3` already gave the *mirror* verb.

**Tech Stack:** bash (sourced modules under `dot_local/bin/`), jj (jujutsu) revsets, chezmoi (source files carry `executable_`/`private_` prefixes; `chezmoi apply` materializes to `~/.local/bin`), bespoke bash test harness under `test/jj-flow/`.

**Spec:** this conversation. Mechanism recap below travels with the plan.

## Global Constraints

- **jj-first, no git mutation.** All history ops via jj. Never `git add`/`git rebase` a jj repo.
- **Never destroy history.** Deconflict in the chain; never flatten/squash to dodge conflicts.
- **Source files, not destinations.** Edit `dot_local/bin/jjflow-catchup.sh` (the chezmoi source); it materializes to `~/.local/bin/jjflow-catchup.sh`. Tests run against the source via `test/jj-flow/lib.sh` (`SCRIPT=$BIN/executable_jj-flow`, `BIN=.../dot_local/bin`), so tests need no `chezmoi apply`. A human runs `chezmoi apply` to deploy.
- **No test that pins a bug green.** Every new test asserts CORRECT behavior.
- **Test seam:** `JJFLOW_CATCHUP_NO_FETCH=1` skips the network fetch (scratch repos have no remote) — set it in every test.
- **Ownership rule (locked):** a wip/* belongs to base `B` iff its **nearest** `local/main*` ancestor is `B`. Chosen over mirror's plainer `descendants(sroot)` because it stays exact even if the graph is tangled/legacy (mixed old-style wip off shared `local/main` + new sibling bases) — which the observed 40+ sweep proves it is. See "Ownership rule" note below.

---

## Mechanism recap (why catchup sweeps everything)

`catchup` scopes by **graph reachability from the base**, not by ownership. Its two rebases (`jjflow-catchup.sh:100-102`):

```sh
catchup_private_root() { roots(TRUNK..BASE); }                            # -s: source + ALL descendants
catchup_mine()         { bookmarks() & descendants(TRUNK..BASE) ~ BASE; } # -b: whole branch
```

`FLOW_BASE` is meant to be this workspace's per-agent base `local/main-<W>` (`jjflow-lib.sh:57-58`), which `jjf base fork` mints by **duplicating** the recipe **onto trunk** (`jjflow-base.sh:33`, `--destination "$FLOW_TRUNK"`) — so every per-agent base is a **sibling off trunk**. With a correctly-resolved sibling base, `descendants(BASE)` is exactly my base + my wip, and both rebases + the conflict gate (`jjflow-catchup.sh:107`) already touch only mine.

The sweep happens when `FLOW_BASE` **silently falls back to the bare shared `local/main`** (`jjflow-lib.sh:46`; the per-agent guard at `:57` didn't fire — no `local/main-<W>` for this workspace). Then `descendants(local/main)` = every wip/* that hangs off shared main (legacy branches, other agents' old-style work), `-s roots(...)` drags all of them, and the conflict gate rolls the whole thing back if **any one** of them conflicts. That is the reported "40+ stale branches block catchup, all-or-nothing."

Fix = stop the silent fallback (Task 1) + scope the restack to owned wip so even a tangled graph can't drag off-base branches (Tasks 2–3).

### Ownership rule

"Nearest `local/main*` ancestor is my base." For a wip `W` and base `B`:
- `W` descends from `B`: `(W) & descendants(B)` non-empty, AND
- no other base between: `(ancestors(W) ~ ancestors(B)) & bookmarks("local/main") ~ B` is **empty**.

`bookmarks("local/main")` is a substring match — matches `local/main` and every `local/main-*` (theoretical false match `local/maintenance` is acceptable; note it). Verify jj's substring semantics during Task 2 build; if jj needs an explicit prefix, use `bookmarks(glob:"local/main*")`.

---

## Task 1: Base-resolution guard — refuse the shared-base fallback in a fleet

**Files:**
- Modify: `dot_local/bin/jjflow-catchup.sh` (add `catchup_guard_base`, call it in `catchup_main` after `flow_load_config`)
- Test: `test/jj-flow/test_catchup_guard.sh` (new)

**Interfaces:**
- Consumes: `flow_load_config` sets `FLOW_BASE`, `FLOW_WS`, `FLOW_TRUNK` (from `jjflow-lib.sh`).
- Produces: `catchup_guard_base` → returns 0 (ok to proceed) or non-zero (refuse, message on stderr). `catchup_main` returns 4 when the guard refuses.

**Signal (intent-free):** refuse iff FLOW_BASE is the bare shared base **and** the repo already has ≥1 per-agent base (a fleet exists). No per-agent bases anywhere ⇒ single-agent/legacy repo, shared base is intended ⇒ allow (no regression).

- [ ] **Step 1: Write the failing test**

```bash
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
echo "ok: catchup_guard"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/jj-flow/test_catchup_guard.sh`
Expected: FAIL — `catchup did not refuse the shared-base fallback` (guard not implemented; catchup instead tries to sweep).

- [ ] **Step 3: Write minimal implementation**

Add to `jjflow-catchup.sh` (before `catchup_main`):

```sh
# catchup_guard_base — refuse to run against the bare shared base when the repo is a
# fleet (≥1 per-agent local/main-* base exists) but THIS workspace has none. Catching
# up the shared stack there drags every legacy/other-agent wip/* off it. Single-agent
# repos (no per-agent base anywhere) are unaffected: shared local/main is the intended
# base. The per-agent base itself is a sibling off trunk (jjf base fork duplicates the
# recipe onto trunk), so a resolved per-agent base already scopes catchup to my stream.
catchup_guard_base() {
  # per-agent base resolved → fine.
  [[ "$FLOW_BASE" == "local/main-$FLOW_WS" ]] && return 0
  # on the shared base: only a fleet (some per-agent base exists) is dangerous.
  local peers
  peers=$(jj bookmark list -T 'if(remote,"",if(normal_target, name ++ "\n", ""))' 2>/dev/null \
            | grep -cE '^local/main-' || true)
  (( peers > 0 )) || return 0
  echo "jj-flow catchup: REFUSING — this workspace is on the shared '$FLOW_BASE' base," >&2
  echo "  but the repo has $peers per-agent base(s). Catching up here would drag every" >&2
  echo "  wip/* on the shared stack. Run 'jjf base fork' to mint local/main-$FLOW_WS," >&2
  echo "  then re-run catchup (it will touch only your stream)." >&2
  return 4
}
```

Call it in `catchup_main`, right after `flow_load_config` (currently `jjflow-catchup.sh:73`) and before the workspace-validate block:

```sh
  flow_load_config
  catchup_guard_base || return $?
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/jj-flow/test_catchup_guard.sh`
Expected: PASS — `ok: catchup_guard`

- [ ] **Step 5: Regression — single-agent repo still catches up**

Add to the same test file, before cleanup, a second scratch repo with only shared `local/main` (no `local/main-*`), one wip, and assert `JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" catchup` exits 0:

```bash
repo2="$(mkrepo)"; cd "$repo2"
mk_layers
jj new local/main >/dev/null 2>&1; echo x > fx; jj commit -m wx >/dev/null 2>&1
jj bookmark set wip/only -r @- >/dev/null 2>&1
JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" catchup >/dev/null 2>&1 \
  || fail "single-agent catchup regressed"
cd / && rm -rf "$repo2"
```

Run: `bash test/jj-flow/test_catchup_guard.sh` → Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add dot_local/bin/jjflow-catchup.sh test/jj-flow/test_catchup_guard.sh
git commit -m "jjf catchup: refuse shared-base fallback in a fleet (stop the 40+ sweep)"
```

---

## Task 2: `catchup_owned_wip` — nearest-base ownership enumeration

**Files:**
- Modify: `dot_local/bin/jjflow-catchup.sh` (add `catchup_wip_bookmarks`, `catchup_owned_wip`)
- Test: `test/jj-flow/test_catchup_owned.sh` (new)

**Interfaces:**
- Consumes: `FLOW_BASE`, `FLOW_WORK_PREFIX` (default `wip/`) from `flow_load_config`.
- Produces: `catchup_owned_wip` → prints, one per line, the wip/* bookmark names whose nearest `local/main*` ancestor is `FLOW_BASE`. `catchup_wip_bookmarks` → prints all local wip/* bookmark names (helper).

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# test_catchup_owned — catchup_owned_wip returns ONLY the wip/* whose nearest
# local/main* base is FLOW_BASE. Sibling bases (base fork = siblings off trunk) and
# legacy wip off a different base are excluded.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 'trunk\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1

# my base + 2 wip
jj new master >/dev/null 2>&1; echo m > pm; jj commit -m rm >/dev/null 2>&1; jj bookmark set local/main-me -r @- >/dev/null 2>&1
jj new local/main-me >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/mine-a -r @- >/dev/null 2>&1
jj new local/main-me >/dev/null 2>&1; echo b > fb; jj commit -m b >/dev/null 2>&1; jj bookmark set wip/mine-b -r @- >/dev/null 2>&1

# a peer base (sibling off trunk) + its wip
jj new master >/dev/null 2>&1; echo p > pp; jj commit -m rp >/dev/null 2>&1; jj bookmark set local/main-peer -r @- >/dev/null 2>&1
jj new local/main-peer >/dev/null 2>&1; echo c > fc; jj commit -m c >/dev/null 2>&1; jj bookmark set wip/peer-c -r @- >/dev/null 2>&1

jj config set --repo jj-mirror.prime-root master >/dev/null 2>&1

owned=$(cd "$repo" && FLOW_BASE=local/main-me FLOW_WORK_PREFIX=wip/ \
  bash -c 'source "'"$BIN"'/jjflow-lib.sh"; source "'"$BIN"'/jjflow-catchup.sh"; catchup_owned_wip' | sort | tr '\n' ' ')
assert_eq "wip/mine-a wip/mine-b " "$owned" "owned set is exactly my two wip"

cd / && rm -rf "$repo"
echo "ok: catchup_owned"
```

> Note: the `bash -c` sources the modules and calls the helper directly with `FLOW_BASE`/`FLOW_WORK_PREFIX` preset, bypassing `flow_load_config`. Confirm `jjflow-lib.sh` sourcing has no side effects that overwrite those; if it does, set them *after* sourcing inside the `-c` string.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/jj-flow/test_catchup_owned.sh`
Expected: FAIL — `catchup_owned_wip: command not found` (or empty output).

- [ ] **Step 3: Write minimal implementation**

Add to `jjflow-catchup.sh`:

```sh
# catchup_wip_bookmarks — local wip-prefixed bookmark names, one per line. Drops
# remote-tracking and non-single-target rows (same guard as mirror's lister).
catchup_wip_bookmarks() {
  jj bookmark list -T 'if(remote,"",if(normal_target, name ++ "\n", ""))' 2>/dev/null \
    | while IFS= read -r name; do
        [[ -n "$name" && "$name" == "$FLOW_WORK_PREFIX"* ]] && printf '%s\n' "$name"
      done
}

# catchup_owned_wip — wip/* whose NEAREST local/main* ancestor is FLOW_BASE.
#  (1) descends from FLOW_BASE, and
#  (2) no other local/main* base lies strictly between FLOW_BASE and it.
# This is the per-branch ownership scoping d534ae3 gave the mirror verb, tightened to
# nearest-base so a tangled/legacy graph (old-style wip off shared main + new sibling
# bases) can't drag an off-base branch into my catchup.
catchup_owned_wip() {
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    jj log --no-graph -r "($name) & descendants($FLOW_BASE)" -T '"x"' 2>/dev/null | grep -q x || continue
    jj log --no-graph \
       -r "(ancestors($name) ~ ancestors($FLOW_BASE)) & bookmarks(\"local/main\") ~ $FLOW_BASE" \
       -T '"x"' 2>/dev/null | grep -q x && continue   # another base sits between → not mine
    printf '%s\n' "$name"
  done < <(catchup_wip_bookmarks)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/jj-flow/test_catchup_owned.sh`
Expected: PASS — `ok: catchup_owned`. If jj rejects `bookmarks("local/main")` as substring, switch both call sites to `bookmarks(glob:"local/main*")` and re-run.

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/jjflow-catchup.sh test/jj-flow/test_catchup_owned.sh
git commit -m "jjf catchup: catchup_owned_wip — nearest-base ownership scoping"
```

---

## Task 3: Rewire `catchup_main` restack + conflict gate to the owned set

**Files:**
- Modify: `dot_local/bin/jjflow-catchup.sh:96-112` (restack + conflict gate)
- Test: `test/jj-flow/test_catchup_scope.sh` (new — the 40+ regression)

**Interfaces:**
- Consumes: `catchup_owned_wip` (Task 2), `catchup_private_root`, `FLOW_BASE`, `FLOW_TRUNK`, the existing `pre_op` + `_catchup_rollback`.
- Produces: after catchup, only `FLOW_BASE` and owned wip/* are rewritten; off-base wip/* keep their original commit ids.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# test_catchup_scope — with a per-agent base plus a peer base carrying 40 wip/*,
# catchup advances MY base + MY wip onto the new trunk and leaves every off-base wip
# UNTOUCHED (same commit id before/after).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
printf 't0\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1

# my base + my wip
jj new master >/dev/null 2>&1; echo m > pm; jj commit -m rm >/dev/null 2>&1; jj bookmark set local/main-me -r @- >/dev/null 2>&1
jj new local/main-me >/dev/null 2>&1; echo a > fa; jj commit -m a >/dev/null 2>&1; jj bookmark set wip/mine-a -r @- >/dev/null 2>&1

# peer base + 40 wip off it
jj new master >/dev/null 2>&1; echo p > pp; jj commit -m rp >/dev/null 2>&1; jj bookmark set local/main-peer -r @- >/dev/null 2>&1
for i in $(seq 1 40); do
  jj new local/main-peer >/dev/null 2>&1; echo "$i" > "g$i"; jj commit -m "p$i" >/dev/null 2>&1
  jj bookmark set "wip/peer-$i" -r @- >/dev/null 2>&1
done

# advance trunk so catchup has something to rebase onto
jj new master >/dev/null 2>&1; echo t1 > ft; jj commit -m M1 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
jj config set --repo jj-mirror.prime-root master >/dev/null 2>&1

before=$(jj log --no-graph -r 'wip/peer-1' -T 'commit_id' 2>/dev/null)

# run catchup as the 'me' agent (force base via config so the test needn't add a workspace)
jj config set --repo jj-flow.base local/main-me >/dev/null 2>&1
JJFLOW_CATCHUP_NO_FETCH=1 "$SCRIPT" catchup -f >/dev/null 2>&1 || fail "catchup errored"

after=$(jj log --no-graph -r 'wip/peer-1' -T 'commit_id' 2>/dev/null)
assert_eq "$before" "$after" "off-base wip/peer-1 was NOT rewritten"
# my wip landed on the new trunk (its ancestors include the new master tip)
jj log --no-graph -r 'wip/mine-a & descendants(master)' -T '"x"' 2>/dev/null | grep -q x \
  || fail "my wip/mine-a was not advanced onto the new trunk"

cd / && rm -rf "$repo"
echo "ok: catchup_scope"
```

> Note: this drives base via `jj-flow.base` config (`jjflow-lib.sh:46` reads it) so the test needs no second workspace. Confirm `flow_load_config` honors that config key and that `catchup_guard_base` passes (per-agent base resolved via config ⇒ `FLOW_BASE=local/main-me`, `FLOW_WS` empty; guard's first check `FLOW_BASE == local/main-$FLOW_WS` is false, but `local/main-*` peers exist ⇒ guard would REFUSE). **Adjust the guard OR the test:** the guard must treat a config-pinned per-agent base as resolved. Simplest: in `catchup_guard_base`, also return 0 when `FLOW_BASE` matches `local/main-*` (any per-agent base, however resolved), only refusing on the *bare* shared base. Update Task 1's `catchup_guard_base` first line to: `[[ "$FLOW_BASE" == local/main-* ]] && return 0` and re-run Task 1's test.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/jj-flow/test_catchup_scope.sh`
Expected: FAIL — `off-base wip/peer-1 was NOT rewritten` assertion trips (current blanket `-b descendants(TRUNK..BASE)` / conflict gate behavior, or peers dragged).

- [ ] **Step 3: Rewrite the restack + conflict gate**

Replace `jjflow-catchup.sh:96-112` (the `# 5.` restack and `# 6.` conflict gate blocks) with an owned-set restack:

```sh
  # 5. restack, SCOPED to the branches this base owns. Lift my base onto trunk (a
  # per-agent base is a sibling off trunk, so -s roots(TRUNK..BASE) carries only my
  # line), then realign each OWNED wip onto the advanced base. Off-base wip/* — other
  # agents' sibling streams, legacy branches on shared main — are never rebased.
  echo "== rebase private stack onto $FLOW_TRUNK (owned wip only) =="
  local _catchup_rollback='jj op restore "$pre_op" >/dev/null 2>&1 || true'
  jj rebase -s "$(catchup_private_root)" -d "$FLOW_TRUNK" >/dev/null 2>&1 \
    || { echo "jj-flow catchup: restack failed; rolling back to op $pre_op" >&2; eval "$_catchup_rollback"; return 1; }

  local owned; owned=$(catchup_owned_wip)
  local w
  while IFS= read -r w; do
    [[ -n "$w" ]] || continue
    jj rebase -b "$w" -d "$FLOW_BASE" >/dev/null 2>&1 \
      || { echo "jj-flow catchup: restack of $w failed; rolling back to op $pre_op" >&2; eval "$_catchup_rollback"; return 1; }
  done <<< "$owned"

  # 6. conflict gate SCOPED to base + owned wip only — an off-base branch's conflict
  # must not roll back my clean catch-up (the all-or-nothing bug).
  local gate="$FLOW_BASE"
  while IFS= read -r w; do [[ -n "$w" ]] && gate="$gate | $w"; done <<< "$owned"
  if jj log --no-graph -r "($gate) & conflicts()" -T '"x"' 2>/dev/null | grep -q x; then
    echo "jj-flow catchup: STOPPED — rebase onto $FLOW_TRUNK would conflict; rolled back to op $pre_op (nothing rewritten)." >&2
    echo "  resolve the conflicting branch(es) on the current base, then re-run." >&2
    eval "$_catchup_rollback"
    return 3
  fi
```

Then delete the now-unused `catchup_mine()` (`jjflow-catchup.sh:28`) — it was the blanket `-b` revset; nothing else references it (grep to confirm net-negative).

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/jj-flow/test_catchup_scope.sh`
Expected: PASS — `ok: catchup_scope`.

- [ ] **Step 5: Run the whole jj-flow suite (no regressions)**

Run: `bash test/jj-flow/run-all.sh`
Expected: all pass, including the existing `test_verbs.sh` / any catchup coverage.

- [ ] **Step 6: Commit**

```bash
git add dot_local/bin/jjflow-catchup.sh test/jj-flow/test_catchup_scope.sh
git commit -m "jjf catchup: scope restack + conflict gate to owned wip (targeted catch-up)"
```

---

## Self-Review

**1. Spec coverage.**
- "Don't sweep all 40+" → Task 1 (guard stops the shared-fallback sweep) + Task 3 (owned-set restack).
- "2–5 sharing a base is fine" → owned set = nearest-base wins; my 2–5 included, peers excluded (Task 2/3 tests).
- "targeted catch-up" → Task 3 conflict gate scoped to owned, so one stale conflict no longer blocks.

**2. Placeholder scan.** All steps carry real bash + revsets. Two flagged verifications (jj `bookmarks("local/main")` substring semantics in Task 2 Step 4; guard-vs-config-base interaction in Task 3 Step 1) are resolved inline with the exact adjustment, not left open.

**3. Type/name consistency.** `catchup_owned_wip` (Task 2) is the exact name consumed in Task 3. `catchup_guard_base` returns 4; `catchup_main` propagates it (`return $?`). `catchup_wip_bookmarks` used only inside `catchup_owned_wip`. `catchup_private_root` reused unchanged; `catchup_mine` deleted (Task 3 Step 3).

## Open decision (surface before build)

**Guard on shared base: refuse (this plan) vs auto-`base fork`.** Plan refuses with an actionable message — predictable, no surprise mutation (matches the "targeted, don't-drag" intent). Alternative: auto-mint `local/main-<W>` and proceed. Refuse chosen; flip to auto only if you'd rather catchup self-heal. One-line change in `catchup_guard_base`.

## What's NOT in this plan

- Aligning the *mirror* verb to the same nearest-base rule (it uses the weaker `descendants(sroot)`; fine for clean siblings). Follow-up if the graph is tangled enough to matter there too.
- Culling the 40+ stale wip/* — separate concern (see `jj-pr-cleanup` / the `test/jj-mirror/test_cull_*` work already in flight).
- A `jjf catchup <bookmark…>` explicit-target form — the owned-set default should remove the need; add later if you want manual override.
