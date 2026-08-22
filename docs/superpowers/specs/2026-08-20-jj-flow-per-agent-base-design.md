# jj-flow — per-agent private base — Design

**Status**: Proposed (2026-08-20)

Extends `2026-08-06-jj-flow-unified-tool-design.md`. Depends on the base-override
(`[jj-flow] base`) already built into `jjflow-catchup.sh`.

## Context

Multiple agents work different PR streams in the same repo, each a jj **workspace**
(lunar: `~/work/lunar/<name>`). They share one private base `local/main` (= master
+ ~7 personal commits: `.envrc`/direnv, pnpm, jj-version fallbacks, local settings
— identical content for every agent, needed so branches build in the jj-no-git
env). Catch-up rebases that shared base **and every agent's `wip/*`** as one atomic
move (`jjflow-catchup.sh`: `rebase -s roots(trunk..base) -d trunk`), so whoever
runs it drags all agents — and a single conflicted branch rolls the whole fleet
back. Agents collide.

## Decision

Give each agent its **own** private base, `local/main-<workspace>`, carrying the
same personal recipe on master. Catch-up (and mirror) operate on the *current
workspace's* base only, so an agent advances its stream without touching anyone
else's. `local/main` remains the **canonical recipe** — the template per-agent
bases are minted from; nobody works on it directly.

```
master  (moves)
  ├─ local/main            canonical recipe (template)
  ├─ local/main-alice      ┬ wip/alice-*     alice's stream
  └─ local/main-bob        ┴ wip/bob-*       bob's stream
```

Chose this (Option C) over borrow-by-recipe-match and one-shared-base-lazy-reanchor
because it has **no shared mutable state and no races** — the least fragile option
that still fits jj-flow's existing `base` key. The cross-agent "borrow" (reuse a
base another agent already rebased) is the fragile part and is **deferred** — C is
additive to it later, gated on real pain.

## The crux: workspace-derived base

**Key jj constraint:** `jj config --repo` writes `.jj/repo/config.toml`, **shared
across all workspaces of a repo** — so the base can't be per-agent via config.
Instead `flow_load_config` derives `FLOW_BASE` from the current workspace:

1. determine current workspace name `W` (match `$PWD`/workspace-root against
   `jj workspace list` roots — see Open questions for the exact mechanism)
2. if `local/main-<W>` exists → `FLOW_BASE=local/main-<W>`
3. else if `[jj-flow] base` is set explicitly → use it (single-agent / override)
4. else → `local/main` (single-agent default; current behavior preserved)

That one derived `FLOW_BASE` feeds **both** consumers — the unifying win:

- **catch-up** rebases `roots(trunk..FLOW_BASE)` + this agent's wip (already
  parameterized; just needs the workspace-derived value).
- **mirror** must base-strip PRs against the agent's base, so jj-flow sets mirror's
  source-root from `FLOW_BASE` before calling `mirror_main` (jj-mirror reads
  `jj-mirror.source-root` from repo-shared config, which is *also* not per-agent —
  so jj-flow passes it in / sets it per-invocation rather than relying on config).

## Verbs

- `jj-flow base fork` — mint `local/main-<W>` for the current workspace: duplicate
  the canonical recipe (`trunk()..local/main`) onto current master, bookmark it.
  Idempotent (no-op if it exists and is current). Run once per agent to opt in.
- `jj-flow base list` — show every `local/main-*`, its drift from master, and which
  wip/PR streams hang off each.
- `jj-flow catchup` — same surface; now scoped to `FLOW_BASE` (this agent's base) +
  its wip. **No-op when `local/main-<W>` is already on current master.**
- `jj-flow status [--graph]` — group by per-agent base when multiple exist; the
  current agent's base highlighted.

## What you get

- **Collision gone** — agent A's catch-up touches only `local/main-A` + `wip/A-*`.
- **No-op when current** — free (catch-up already short-circuits when base is on trunk).
- **Token savings** — each catch-up rebases only that agent's small stack.
- **Backward compatible** — no `local/main-<W>`? falls back to `local/main`; a
  single-agent repo is unchanged.

## Failure modes / edges

| Situation | Behavior |
|---|---|
| No `local/main-<W>` yet | falls back to `local/main`; `jj-flow base fork` opts in |
| Canonical recipe changes (new personal commit) | agent re-forks (or cherry-picks); NOT auto-propagated (v1) |
| Two agents, same wip suffix | disjoint by workspace; bookmarks are repo-global but each agent touches only its own |
| Agent's base conflicts with master on catch-up | rolled back per the existing op-restore safety; only that agent affected |
| Mirror orphan-cull across agents' `ijcd/*` | cull must be scoped so agent A's sync doesn't cull agent B's PRs (see Open questions) |

## Non-goals (v1)

- **Borrow / dedup of base rebases** across agents — the fragile part; deferred to
  a later pass, additive on top of C.
- **Auto-propagating recipe changes** to all agent bases.
- **Cross-agent locking** — none needed; C has no shared mutable state.

## Open questions (resolve in the plan)

1. **Current-workspace-name mechanism** — does jj 0.43 expose it directly, or do we
   match `$PWD` against `jj workspace list` roots? Verify in a scratch repo.
2. **Mirror source-root hand-off** — set `jj-mirror.source-root` per-invocation, or
   thread `FLOW_BASE` into `mirror_main` as a parameter? Prefer not mutating shared
   config.
3. **Mirror orphan-cull scoping** — with per-agent `ijcd/*`, the repo-wide cull must
   not delete another agent's PR bookmarks. Scope by base? By an agent tag?

## Testing

Scratch-repo harness (as `test/jj-catch-up`), plus multi-workspace fixtures:
- workspace-derived `FLOW_BASE` resolves to `local/main-<W>`, falls back cleanly.
- `base fork` mints the recipe on master; idempotent.
- agent A catch-up moves only `local/main-A` + `wip/A-*`; `local/main-B` + `wip/B-*`
  untouched.
- no-op when the agent's base is already current.
- mirror base-strips against the agent's base (PR contains only its feature commits).

## What's NOT in this spec

- No implementation. Next: `docs/superpowers/plans/2026-08-20-jj-flow-per-agent-base.md`.
- Borrow mechanism — separate future spec.
