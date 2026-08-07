# jj-mirror — merge-based resync — Design

**Status**: Proposed (2026-08-06)

Extends `2026-07-15-jj-mirror-design.md`. Read that first for the base model.

## Context

The prime chain is re-derived every sync by strict cherry-pick (`sync_thread`,
`jj duplicate`). "PR stability" is preserved *only* by the positional no-op
reuse: keep an existing prime commit iff `parent == prev` **and**
`diff_hash(existing) == diff_hash(source)` (`executable_jj-mirror:785`). The
moment either fails, `cascade=1` rebuilds every commit from that position down
with **new commit IDs** — dest bookmarks move sideways — jj-vine force-pushes.

Two triggers fire this on a live PR:

| Trigger | Why the keep-condition fails | Result |
|---|---|---|
| Prime root advances (master moved) | first prime commit's parent ≠ new prime root → cascade from commit 0 | whole stack force-pushed |
| Edit an early source commit | `diff_hash` mismatch at that position → cascade downstream | everything below force-pushed |

`--allow-backwards` (`:721`) is the tell — the tool expects sideways moves.
That is the force-push churn: review comments detach on every affected PR.

## Decision

Add an **append-only invariant** for prime bookmarks that already back an open
PR: such a bookmark may only ever advance to a **descendant** of its current
commit — never sideways, never backwards. Descendant-only push = fast-forward =
no force-push = comments survive.

**Mode is chosen per member, not per thread** (handles mixed single/stacked
usage and partially-pushed stacks):

- dest bookmark has an **open PR** → **merge-forward** (append-only).
- dest bookmark has **no open PR** → **clean cherry-pick** (today's path; the
  "initial rebase" — force is free, there is no PR to churn).

## Merge-forward mechanic

Base-bump and content-edit are the same DAG move. For a member with source
commit `SCID`, current downstack base tip `prev`, existing live prime tip `E`:

```
D  = jj duplicate SCID --destination prev     # derived content, base-stripped (as today)
F  = jj new prev E                            # two-parent merge — SHAPE ONLY
     jj restore --from D --into F             # force tree(F) := tree(D)
     jj abandon D
assert E in ancestors(F)                      # append-only invariant — else fail (rolls back)
jj bookmark set <dest> -r F                   # forward-only; no --allow-backwards
```

- **first-parent = `prev`** → jj-vine's `parents.first()` (`src/submit.rs:50-59`)
  still derives the base: new master at the stack bottom, new downstack tip
  mid-stack. `prev` is also F's content root.
- **second-parent = `E`** → F is a **descendant** of E → fast-forward holds.
- **`tree(F) := tree(D)`** → PR diff-vs-base is always exactly the source-derived
  content, and the merge **cannot conflict** (we hard-set the tree; git's 3-way
  never decides it). Source-side conflicts stay the user's problem, per the base
  spec's Conflict handling. If `D` itself is a cherry-pick conflict, detection is
  unchanged: `return 2`, thread rolls back.

Verified on jj 0.43.0 (scratch repo): `jj new A B` → parent index 0 = A
(`parents.map(...)` preserves index order); `restore --from D --into F` in the
clean base-bump is a no-op because auto-merge already equals `D` (so it never
breaks the clean case, only rescues the conflicting one); `E` is an ancestor of
`F`.

Cascade still propagates content (edit B → C moves) but as **one appended merge
per downstream live PR**, fast-forward, not a rewrite.

## Generalized keep / no-op condition

The keep-condition becomes first-parent-aware but otherwise identical, and it
**unifies across both modes** because `range_diff_hash(first_parent, existing)`
gives the per-member diff whether `existing` is a single-parent cherry-pick or a
two-parent merge:

> keep iff `first_parent(existing) == prev`
> **and** `range_diff_hash(first_parent(existing), existing) == diff_hash(source)`

`first_parent` is read order-preserving via
`parents.map(|p| p.commit_id().short()).join("\n") | head -n1` — **not** the `-`
operator, which returns parents unordered.

Unchanged members produce no commit and no push, so a stack does not accrue a
merge commit every sync — only when content or base actually moved.

## Live detection

One `gh pr list --state open --json headRefName -q '.[].headRefName'` per sync
builds the set of dest branches with open PRs. Consulted only for members that
already failed the keep-condition (would touch the bookmark anyway), so no-op
syncs make no network call.

**Injectable for tests / offline:** resolution order is

1. `JJ_MIRROR_LIVE_PRS` env var (space-separated dest bookmark names) — the test
   seam; the tool has no other forge coupling and the test harness has no network.
2. `gh pr list …` if `gh` is on PATH.
3. Fallback: dest has a remote-tracking ref (`<dest>@<remote>` present) →
   treat as live, with a one-time warning that `gh` was unavailable.

## Blast radius

| Function | Change |
|---|---|
| `live_pr_set` (new) | resolution order above; single gh call; memoized per process |
| `advance_merge` (new) | the mechanic above; asserts append-only; forward-only bookmark set |
| `sync_thread` (`:733`) | keep-condition → first-parent-aware; rebuild branch picks `advance_merge` (live) vs existing clean build (not live) per member |
| `squash_thread` (`:818`) | single-PR merge-forward when its dest is live |
| `thread_verdicts` (`:868`) | first-parent-aware keep; new `merge-forward` action alongside keep/diff/cascade — stays in lockstep with sync (`:782`) |
| `set_dest_bookmarks` (`:710`) | clean path keeps `--allow-backwards`; live moves go through `advance_merge` forward-only |
| status / `--graph` / dry-run | surface `merge-forward` so dry-run still predicts truth |

## Non-goals

- No rewrite of the clean cherry-pick path for never-pushed primes.
- No squashing/cleanup of accumulated merge commits — they vanish when the PR
  merges and the branch is deleted.
- No change to orphan cull, abandon, or thread detection.
- No new network dependency on the no-op / status path — only stale live members
  trigger the gh call.

## Testing

Plain-bash harness (`test/jj-mirror/`, `source lib.sh`, `mkrepo`, assert via
`jj log`, `run-all.sh`). Live detection is exercised via `JJ_MIRROR_LIVE_PRS`
(no network in tests). New scenarios:

- base bump, single live PR → merge-forward; old tip is ancestor of new (ff); no
  sideways move.
- content edit mid live stack → one appended merge + append-cascade to each
  downstream live PR; every move a fast-forward.
- non-live member still clean-cherry-picks (regression: existing `test_sync_*`
  stay green).
- no-op stays no-op (no gh call, no commit).
- `parents.first()` of a merge-forwarded member is its base (jj-vine base
  derivation intact).
- dry-run predicts `merge-forward` for a live stale member, `cascade`/`diff` for
  a non-live one.

## What's NOT in this spec

- No implementation. Next: the plan at
  `docs/superpowers/plans/2026-08-06-jj-mirror-merge-resync.md`.
- No opinion on cleaning historical force-push damage on PRs already churned —
  this prevents future churn only.
