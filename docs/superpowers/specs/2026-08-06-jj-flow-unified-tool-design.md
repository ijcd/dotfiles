# jj-flow — collapse the jj-* toolchain into one porcelain — Design

**Status**: Proposed (2026-08-06)

Supersedes the *composition* of `jj-mirror`, `jj-catch-up`, `jj-integrate`,
`jj-refresh-workspaces`, `jj-tug`, `jj-cleanup` — not their logic, which is
re-homed. Builds on `2026-08-06-jj-mirror-merge-resync-design.md`.

## Context

Six tools implement one workflow: maintain a personal stack and project it to
GitHub PRs. They share a model none of them owns:

```
              ADVANCE private            PROJECT to published        RETIRE
   master ───────────┐
     │               │  rebase (catch-up)
   local/main ◀───────┘
     │  wip/*  ───────── mirror/sync (merge-forward) ──▶ ijcd/*  ── vine push
     │    │                                                │
   local/integration                                    (PR merges)
     (octopus of wip/*)                                     │
                                                         cleanup ◀─┘
```

- **catch-up, tug, integrate, refresh-workspaces** advance the *private* side
  (rebase; local; disposable).
- **mirror + vine** project it to the *published* side (merge-forward; stable refs).
- **cleanup** retires a merged PR.

The sprawl causes real bugs. The invariant "published (`ijcd/*`) branches are
base-stripped onto `trunk()`, never descendants of `local/main`" lives NOWHERE:
`jj-mirror` produces it via its `prime-root` config; `jj-catch-up`'s `mine`
revset (`descendants(trunk()..local/main)`) *assumes* it but can't enforce it. If
`prime-root` drifts to `local/main`, `restack-mine` rewrites the PRs every
catch-up — the observed "duplicated/orphaned commits + PR force-push" mess. Each
tool also re-implements config loading, workspace listing, bookmark listing, and
live-PR detection independently.

## Decision

One porcelain, **`jj-flow`**, over one shared library, `jjflow-lib.sh`. Verbs are
the workflow phases. The shared library owns the model — one config, one set of
revsets, one workspace layer, and the guarded base invariant both phases call.

`jj tug` stays the ergonomic front door (its jj alias retargets to
`jj-flow tug`); you never type `jj-flow tug` in daily use. `jj-vine` stays
external — `jj-flow` shells to it, as `jj-mirror` does today.

## Model — the states a branch moves through

The status vocabulary IS the shared model. Each `wip/*` branch is in one state:

| Glyph | State | Meaning |
|-------|-------|---------|
| `○` | draft | local only; no `ijcd/*` yet |
| `◐` | mirrored | `ijcd/*` exists (or has an unpushed ff update); no open PR, or a fast-forward waiting |
| `●` | live | open PR; `ijcd/*` pushed |
| `⚠` | stuck | base divergence — sync can't clear it by re-running (jj-mirror's existing detection) |
| `✓` | merged | PR merged → cleanup candidate |

Drift vs trunk: `even` / `N behind` / `conflict`. Every verb is "drive a branch
from state X to state Y." `catchup` closes drift; `push` moves `◐→●`; `cleanup`
retires `✓`.

## Command surface

| Verb | Re-homes | Does |
|------|----------|------|
| `jj-flow status [--graph]` | (new) | The whole picture — layers, per-branch state, PR, drift, workspace health |
| `jj-flow catchup [-f]` | jj-catch-up + jj-refresh-workspaces + jj-integrate catchup | fetch → rebase **private** stack onto trunk → rebuild integration → refresh workspaces; conflict-gated; never touches `ijcd/*` |
| `jj-flow push [-t <br>]` | jj-mirror + jj-vine | merge-forward `ijcd/*` → vine submit (fast-forward) |
| `jj-flow mirror [-n]` | jj-mirror sync | just the projection (no vine), for inspection |
| `jj-flow integrate …` | jj-integrate | manage `local/integration` membership |
| `jj-flow tug [--all]` | jj-tug | advance nearest bookmark to `@-` |
| `jj-flow cleanup <pr>` | jj-cleanup | retire merged PR (bookmarks, workspace, dir, tab) |
| `jj-flow ship` | (composition) | `catchup` → `push`, conflict-gated between |

## status — the keystone view

Plain:

```
$ jj-flow status
  trunk   master             @ 4a1f   3 behind origin  → catchup
  base    local/main         @ 9c2e   2 commits · on trunk ✓

  BRANCH        STATE       PR      vs TRUNK      WORKSPACE
  wip/auth      ● live      #123    even          auth      ✓
  wip/parser    ◐ mirrored  #124    1 behind ⟳    parser    ✓
  wip/spike     ○ draft     —       3 behind      —         (none)
  wip/flaky     ⚠ stuck     #125    conflict      flaky     ✎ WIP
  wip/old       ✓ merged    #119    —             old       → cleanup

  integration  local/integration @ 7f3d  octopus of 4 · 1 stale ⟳
  next    catchup — 2 wip behind trunk · push — wip/parser ff-ready for #124
```

## status --graph — generalize the beloved mirror graph

The current `jj-mirror status --graph` renders source→prime edges with `●/◐/○`
glyphs grouped by root, plus a base-divergence footer. `jj-flow` keeps that edge
and glyph vocabulary verbatim but **roots it in the private-stack topology** and
annotates PR/workspace state:

```
$ jj-flow status --graph

  master  4a1f   (3 behind origin ⟳ catchup)
    │
    ● local/main  9c2e
    │
    ├─● wip/auth   ──▶ ● ijcd/auth    #123 live
    │
    ├─◐ wip/parser ──▶ ◐ ijcd/parser  #124 · ff update ready ⟳
    │
    ├─○ wip/cache  ──▶ ○ ijcd/cache   mirrored, unpushed
    │
    ├─○ wip/spike                     draft — no PR
    │
    └─⚠ wip/flaky  ──▶ ◐ ijcd/flaky   #125 · base divergence
                          ⚠ cfg.toml — master edits it; deconflict or drop from base

  local/integration  7f3d  ═╡ octopus: auth, parser, cache, spike  (parser stale ⟳)

  legend  ● live   ◐ mirrored / ff-ready   ○ local   ⚠ attention   ✓ merged
```

- `──▶` projection edges and `●/◐/○` glyphs are the existing mirror graph.
- New: the `master → local/main → wip/*` spine, PR numbers + live/ff state, the
  integration octopus line, and the inline base-divergence note (today's footer,
  now attached to its branch).
- The per-pair root `*` marker and source→prime grouping from the current graph
  survive as a `--graph --roots` detail mode for repos with per-thread root
  overrides (keeps the existing coalescing layout available, not the default).

## Shared library — `jjflow-lib.sh`

One home for what the six tools re-derive. Sourced by every verb.

- **`load_flow_config`** — reads `[jj-flow]`; falls back to `[jj-mirror]` /
  `[jj-integrate]` keys during migration so nothing breaks mid-flight.
- **Revsets** — `mine`, `prime_chain`, thread detection, `layers` (trunk / base /
  wip / prime).
- **Workspaces** — list / validate / snapshot / refresh (today's
  `jj-refresh-workspaces` + catch-up's validation).
- **Live-PR detection** — the batched `gh pr list` + injection seam already built.
- **`assert_prime_base`** — errors if any `pr-prefix` bookmark is a descendant of
  `base` (i.e. caught by `mine`). Both `catchup` and `push` call it. This is the
  guard that makes the "ijcd/* on the wrong base" mess structurally impossible —
  the invariant finally has an owner.

## Config consolidation

```toml
[jj-flow]
trunk         = "trunk()"
base          = "local/main"
work-prefix   = "wip/"
pr-prefix     = "ijcd/"          # ONE place — no drift between mirror & restack
integration   = "local/integration"
workspace-dir = "~/work/lunar"
remote        = "origin"
```

Replaces `[jj-mirror]` + `[jj-integrate]` + the `mine`/root revset aliases +
catch-up's implicit assumptions. The `restack*` jj aliases either retarget through
`jj-flow` or are dropped in favour of `jj-flow catchup`.

## Migration — incremental, always shippable

- **P0 — extract `jjflow-lib.sh`**, point the existing six scripts at it. Kills the
  drift bugs (one `assert_prime_base`, one config) with no rename, no new surface.
- **P1 — build `jj-flow status` [--graph]** over the lib. Net-new; zero migration
  risk; pins down the state vocabulary the rest depends on.
- **P2 — fold verbs** one at a time; each old tool becomes a one-line shim
  (`exec jj-flow <verb> "$@"`). Tests move with each verb.
- **P3 — retire shims** once muscle memory moves — except `jj tug`, whose alias
  stays retargeted to `jj-flow tug`.

Each phase leaves a working toolchain.

## Non-goals

- No behavior change to the *rebase* on the private side — catch-up keeps rebasing
  `local/main` + `wip/*` (local, correct). Merge is only on the published side
  (already built in jj-mirror).
- No new remote/network on the no-op or status-without-`gh` path (status degrades:
  PR column shows `?` when `gh` is absent).
- No rewrite of jj-vine — external, shelled to.
- No auto-run of `push` inside `catchup` — the conflict gate between them is the
  point; `ship` opts into both.

## Testing

- P0: the existing 42 jj-mirror tests + jj-cleanup/integrate/tug suites keep
  passing against the shared lib (behavior-preserving extraction).
- P1: golden-output tests for `status` / `status --graph` across the state matrix
  (draft / mirrored / live / stuck / merged; drift even / behind / conflict;
  workspace ok / WIP / missing), driven by the same scratch-repo + `JJ_MIRROR_LIVE_PRS`
  injection harness.
- `assert_prime_base` test: a `pr/*` planted on `local/main` must error loudly.

## What's NOT in this spec

- No implementation. Next: the plan (`docs/superpowers/plans/2026-08-06-jj-flow.md`),
  starting with P1 `status` to lock the state vocabulary.
- No decision on the tool's final name (`jj-flow` vs `stack` vs `jjf`) — cosmetic,
  settled at P2 when the dispatcher lands.
- No opinion yet on whether `catchup` should collapse `restack` + `restack-mine`
  into a single private-stack rebase — decided once the lunar probe shows whether
  the two-rebase sequence is redundant.
