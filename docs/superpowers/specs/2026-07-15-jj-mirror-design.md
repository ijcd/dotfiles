# jj-mirror — Design

**Status**: Proposed (2026-07-15)

## Context

Two branch styles serve different needs:

- **WIP thread** — where daily work happens. Small commits, spikes, local-only experiments, half-formed refactors. Never pushed. Content-organized however you think.
- **Prime thread** — the review-clean version. Same code work, but each commit is a coherent unit ready to become a PR. jj-vine pushes these and manages the PRs.

Today, keeping the two threads in sync is manual: you rework, cherry-pick, rebase, and hope jj-vine doesn't force-push GitHub PRs into a "reviews reset, comments detached" state.

Goal: a tool that maintains the prime thread as a derived view of the WIP thread — mechanically, resiliently, and without churning PRs. Work stays on WIP, `jj-mirror sync` produces or updates prime, jj-vine pushes prime unchanged.

## Prior art

**jj-vine** (`codeberg.org/abrenneke/jj-vine`) — the tool jj-mirror partners with. Two facts about its design shape ours:

1. **PR identity = bookmark name.** jj-vine looks up PRs by `headRefName` on the forge each run (`src/forge/github.rs:753-798`). No local mapping. Same bookmark name across syncs → same PR persists.
2. **Base branch derived per-run.** `mr_base_branch()` at `src/submit.rs:50-59` reads `parents.first()` bookmark on each call. Insert a bookmark in the middle of a stack and jj-vine automatically re-parents the downstream PR.

So the "not wonky" contract is exactly: keep prime bookmarks stable across syncs. jj-vine handles the rest.

**Existing jj scripts in the repo** — `dot_local/bin/executable_jj-catch-up`, `executable_jj-refresh-workspaces`. POSIX sh, banner comment, `set -eu`, short flags. jj-mirror follows the same style but uses bash (needs associative arrays).

## Model

Two disjoint bookmark namespaces, both under `mine`:

- **Source bookmarks** — user-placed on WIP commits they want mirrored. Never pushed. Default prefix `wip/`, **configurable**.
- **Prime bookmarks** — owned by jj-mirror, live on a separate branch off `trunk()`, one per thread. Tracked by jj-vine → become the PRs. Default prefix `pr/`, **configurable**.

**Pairing** is by suffix. Default: `wip/foo` ↔ `pr/foo`. Any bookmark not matching either configured prefix is invisible to jj-mirror — this is where `A` and other WIP scaffolding lives, either unbookmarked or with a bookmark name that doesn't collide.

**Threads** — a linear chain of source bookmarks descending from `trunk()` through a single path. Multiple parallel threads = multiple disjoint chains, each producing its own prime branch off trunk. Grouping is graph-topological, **not name-based** — no `<thread>/<name>` naming discipline required.

**Prime content** is strict cherry-pick: each `<prime>/x` commit contains **only** its paired source commit's own diff, applied on top of the previous prime commit (or `trunk()` for the first). WIP-only commits between mirrored ones are invisible on the prime side. Corollary: mirrored source commits must be authored so their diff is portable (doesn't depend on non-mirrored intervening code). That discipline is on the user.

## Configuration

Under `[jj-mirror]` in `.jj/repo/config.toml` (per-repo) or `~/.config/jj/config.toml` (global). Mirrors jj-vine's convention.

```toml
[jj-mirror]
source-prefix = "wip/"        # default — shown for illustration; strings are free-form
prime-prefix  = "pr/"         # default — shown for illustration; strings are free-form
```

Both keys are free-form strings. `""` (empty) is legal for either — matches every bookmark, useful if the user wants to key on a different convention entirely (e.g., prime bookmarks all live under `feature/` and there's no source prefix). Precondition: the two prefixes must not overlap (source is a prefix of prime, or vice-versa, is rejected at startup).

Read via `jj config get jj-mirror.source-prefix` with defaults if unset.

Design principle: **the strings "wip" and "pr" appear nowhere in the code path.** All references go through `$SOURCE_PREFIX` / `$PRIME_PREFIX` variables loaded once at startup.

## Sync algorithm

State-free. Every invocation re-derives from the jj graph and mutates only what's stale.

```
sync():
  for thread in detect_threads():
    source_chain  = ordered source bookmarks on this thread (DAG order from trunk())
    prime_chain   = ordered prime bookmarks on this thread's prime branch
    expected      = [strip_source_prefix(w) for w in source_chain]

    # 1. Cull orphans: prime bookmarks with no matching source bookmark
    for prime_name in prime_chain - {PRIME_PREFIX+x for x in expected}:
      abandon commit at prime_name
      jj bookmark delete prime_name

    # 2. Walk expected, ensure each prime bookmark is correct
    prev = trunk()
    for x, w in zip(expected, source_chain):
      prime_name = PRIME_PREFIX + x

      if prime_name exists at commit P
         and parent(P) == prev
         and diff_hash(P) == diff_hash(w):
        prev = P
        continue        # up-to-date, no touch, no push

      if prime_name exists: abandon(P); delete_bookmark(prime_name)
      new = jj duplicate w --destination prev
      jj bookmark set prime_name -r new
      prev = new
```

**`diff_hash(commit)`** — SHA-256 of a deterministic patch representation for `commit` vs. its parent. Implementation: `jj diff -r <commit> --template <fixed template> | shasum -a 256`. Template emits file list + blob hashes, not free-form text — stable across whitespace-preserving jj versions.

**No-op path** is the win: when nothing changed, no bookmarks move, no commits are rewritten, no push happens. That's how PR stability actually manifests — jj-vine's next `submit --tracked` sees no bookmark movement and pushes nothing.

**Cascade on rebuild**: prime commits are linearly stacked, each child's content depends on parent identity. Rebuilding `<prime>/x` forces rebuilding all `<prime>/y` for y after x in this thread. Intrinsic to strict cherry-pick.

## Thread detection

A **thread root** is a bookmark whose commit's parent is (transitively) `trunk()` without passing through another source bookmark. A **thread** is one such root plus all source bookmarks reachable from it forward through a single path.

Implementation:

1. Enumerate source bookmarks: `jj bookmark list -r 'mine()' -T ...`, filter by `SOURCE_PREFIX`.
2. For each, compute the ordered ancestor list within `trunk()..@`.
3. Group into threads by the deepest common ancestor that's a source bookmark. Bookmarks with no source-bookmark ancestor are thread roots.

Prime bookmarks are grouped the same way. Pairing links by `strip(source_prefix, name) == strip(prime_prefix, name)`.

## Commands

```
jj-mirror                             # alias for `sync` if no args
jj-mirror sync [--dry-run] [--thread <root>]
jj-mirror status                      # list threads, source/prime, staleness per pair
jj-mirror push                        # sync, then invoke jj-vine (`jj vine submit --tracked`)
jj-mirror abandon <name>              # delete both <source>/name and <prime>/name, abandon commits
```

Flags follow the style of `jj-catch-up` — short single-letter aliases for repeated use:

- `-n` = `--dry-run`
- `-t <root>` = `--thread <root>`

`jj-mirror push` is a convenience wrapper. If jj-vine isn't installed, print a hint and exit non-zero — don't fail silently.

The user's declared operation set maps naturally:

- **create** — place a `<source>/foo` bookmark on a WIP commit; `sync` creates `<prime>/foo`.
- **add at end** — commit + `<source>/bar` on the tip; `sync` appends.
- **add in middle** — insert commit + bookmark between existing source bookmarks; `sync` inserts prime commit, cascades downstream.
- **abandon** — delete `<source>/foo` (or run `jj-mirror abandon foo`); `sync` culls `<prime>/foo`.
- **edit** — amend the commit at `<source>/foo`; `sync` detects diff-hash mismatch, rebuilds `<prime>/foo`.

## Conflict handling

`jj duplicate w -d prev` can produce an **in-tree conflict** (jj represents conflicts as commit state, doesn't halt on them). Detection: after each duplicate, check `jj show <new> --template 'if(conflict, "yes", "no")'`.

On conflict:

1. `jj op restore <op-id-captured-before-sync>` — atomic rollback of every mutation this sync did.
2. Print: which `<source>/x` failed to apply on which `<prime>/(x-1)`, the conflicted files.
3. Suggest: rework `<source>/x` so its diff is independent of non-mirrored ancestors, or reorder within the source chain.

Exit non-zero.

The `jj op` capture at start-of-sync is the resilience anchor. Any failure — conflict, external interruption, bug in the tool — leaves the repo recoverable via `jj op restore`.

## Failure modes handled

| Situation | Behavior |
|---|---|
| User manually deletes `<prime>/foo` bookmark | Next sync recreates it |
| User manually edits a prime commit | Diff-hash mismatch → next sync rebuilds it (manual edit lost — expected in strict mode) |
| User rebases source thread onto new trunk | `prev = trunk()` at each thread walk → prime cherry-picks onto new trunk |
| Two source bookmarks on the same commit | Sync errors: "ambiguous pairing, one source bookmark per commit" |
| Source bookmark and unrelated bookmark on same commit | Ignored — only `SOURCE_PREFIX` bookmarks are considered |
| `jj-mirror sync` while another jj op is running elsewhere | jj serializes ops; safe |
| Cherry-pick conflict | `jj op restore`, exit non-zero, print diagnostics |
| Configured prefix is empty (`""`) | Every bookmark matches; user must ensure disjoint namespaces some other way |
| `SOURCE_PREFIX` and `PRIME_PREFIX` overlap | Startup validation rejects, exits non-zero |

## Non-goals

- **Bidirectional sync.** Prime is derived from source. Editing prime directly is undefined behavior — next sync overwrites it.
- **Content-preserving merges across syncs.** If source-side diff changes, prime commit is rebuilt from scratch. No attempt to preserve jj change IDs on prime — bookmark names carry PR identity, that's enough.
- **Non-linear threads.** DAG source threads (merges) are out of scope for v1. Real linear stacks only. Error clearly if encountered.
- **Auto-sync hooks.** No `chpwd`/`jj op post-commit` hook. Sync is on-demand.
- **Fork mode.** jj-vine has a fork-repo mode that collapses PRs onto default branch (loses stack layering). jj-mirror doesn't detect or care — user's forge config problem.

## Language and location

**Bash** at `dot_local/bin/executable_jj-mirror` (chezmoi prefix → `~/.local/bin/jj-mirror`, executable).

Rationale: matches the shell-out-heavy pattern of `jj-catch-up` and `jj-refresh-workspaces`. Real logic lives in `jj` templates and revsets; bash is glue. Associative arrays are needed for the source ↔ prime pairing table, so plain POSIX `sh` doesn't fit.

**Dependencies**:
- `jj` (any recent version supporting `--template` on `bookmark list`, `duplicate`, `op restore`)
- `shasum` (BSD stock on macOS — used instead of `sha256sum` for portability)
- `jj-vine` — only needed for `jj-mirror push`; other commands work without it

No `jq`, no python, no Node.

**Style**: banner comment header per the repo convention. `set -euo pipefail` — pipefail matters especially for the diff-hash pipelines (silent hash of empty input on jj-side failure would be a nasty bug). Short flags for common options.

## Testing plan

Not TDD-heavy — this is a shell script gluing to `jj`. Focus on:

- **Smoke script** in `test/` that uses `jj init` in a tmp dir, sets up known WIP/prime shapes, runs `jj-mirror sync`, asserts on `jj log` output.
- **Fixture scenarios**:
  - Empty prime, one source thread with 3 bookmarks — expect 3 prime bookmarks created.
  - Re-sync unchanged: expect zero jj operations logged since last sync.
  - Edit a middle source bookmark: expect one prime rebuild + cascade.
  - Insert a source bookmark in middle: expect prime insert + cascade.
  - Abandon a source bookmark: expect prime orphan cleanup.
  - Two parallel threads: expect two prime branches, no cross-contamination.
  - Cherry-pick conflict: expect `jj op restore` runs, exit code non-zero, error mentions the failing bookmark.
- **Manual verification** with a real repo + jj-vine + a scratch GitHub repo: run through create/edit/insert/abandon over a few PRs, confirm PR review threads don't detach.

## What's NOT in this spec

- No implementation. Next step is `writing-plans`.
- No opinion on where `jj-mirror push` should invoke jj-vine's binary. `jj vine` alias vs. `jj-vine` standalone — decided at implementation time based on how the user installs it.
- No `jj-mirror init` command. Prefixes have defaults; per-repo overrides are `jj config set`. No wizard.
- No performance tuning. Threads with hundreds of source bookmarks are theoretical, not real for this use case.
