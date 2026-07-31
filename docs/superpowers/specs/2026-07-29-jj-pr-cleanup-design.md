# jj-pr-cleanup — tear down a merged/closed PR's branch + workspace

**Status**: Design (2026-07-29)

Clean up everything left behind when a PR is closed and merged to `master`: local + remote bookmarks, the jj workspace, its directory, and its kitty tab — parking any unmerged work first so nothing is lost. Confirm before mutating.

## Context

The lunar toolchain (see `2026-07-15-jj-mirror-design.md`, `private_dot_claude/skills/jj-pr-workflow/`):

- **`local/main`** — permanent, local-only base. Holds personal commits (settings, env, jj fallbacks). Never pushed, never in a PR. `wip/*` stack on it.
- **`wip/<suffix>`** — feature work, based on `local/main`. Its thread is `local/main..wip/<suffix>`.
- **`ijcd/<suffix>`** — the machine-owned prime `jj-mirror` replays from the `wip` thread onto `master` (base stripped), pushed by `jj-vine` as the PR head branch.
- **Workspace** — `~/work/lunar/<suffix>`; jj workspace `--name` == `<suffix>` == dir basename. `default` (main repo) and `local-main` workspaces also exist.
- **kitty tab** — `runclaude` titles it `cc:<suffix>`.
- `trunk()` = `master@origin`. `jj-mirror` config: `source-prefix=wip/`, `prime-prefix=ijcd/`, `source-root=local/main`, `prime-root=master`.

When a PR merges, all of this lingers. Manual teardown is error-prone and risks nuking unpushed work.

## Decision

Ship **two artifacts**: a tested bash tool for the mechanism, a skill for the judgment.

- **`dot_local/bin/executable_jj-cleanup`** + `test/jj-cleanup/` suite — same pattern as `jj-mirror`/`jj-integrate`/`jj-tug`. Destructive logic (remote branch delete, `rm -rf`) is unit-tested, not re-derived per run.
- **`private_dot_claude/skills/jj-pr-cleanup/SKILL.md`** — orchestration SOP: run `scan`, present the plan, name `todo/<name>` parks descriptively, get explicit confirm, `teardown` each pick.

Rejected: **skill-only** (destructive steps untested — against the repo's tested-tool convention for exactly this class of op); **script-only w/ fzf TUI** (user asked for a skill; naming parks + judging edge cases is where Claude earns its keep).

## Components

### `jj-cleanup scan`
Read-only. For each workspace suffix (excluding the denylist):
1. `jj git fetch` once up front so `trunk()` + PR state are current.
2. PR state: `gh pr view ijcd/<suffix> --json state,mergedAt` (keyed off the `ijcd/<suffix>` head branch).
3. Print one row: `suffix · PR state · remote ijcd? · lost-commits(n) · kitty tab?`.

Eligible for teardown = PR state **MERGED or CLOSED**. Rows that can't be confirmed (gh error, no PR, VPN down) print with a reason and are **never** auto-selected.

### `jj-cleanup teardown <suffix> [--park todo/<name>] [--dry-run]`
The 6 steps below, atomic per workspace, `--dry-run` prints exact commands.

### `jj-pr-cleanup/SKILL.md`
Runs `scan`, renders the table, proposes descriptive `todo/<name>` for any lost work, gets the user's explicit go/no-go, then calls `teardown` per selected suffix. Confirm-before-acting lives here.

## Detection — squash-safe, `local/main`-anchored

- **Merged/closed**: authoritative from `gh` (`mergedAt`). Squash-merge changes commit SHAs on `master`, so no jj ancestry test can prove "merged" — gh is the source of truth.
- **Would-be-lost** = commits in `local/main..wip/<suffix>` that never reached the merge = the tail *ahead of the mirrored prime* (`jj-mirror`'s sync verdict: `wip` ahead of `ijcd/<suffix>`), **plus** any uncommitted changes in the workspace `@`. This never relies on per-commit SHA/patch matching (which squash defeats).
- The window is **always** `local/main..wip/<suffix>` — obtained by reusing `jj-mirror`'s `source-root` (resolves to `local/main`), never hardcoded, never `trunk()`. Using `trunk()..` would wrongly sweep the personal base commits (settings/env) in as feature work.

## Teardown — park before delete

| # | Step | Command |
|---|------|---------|
| 1 | **Park** lost commits (if any) | `jj rebase -r <unmerged-tail> -d local/main` then `jj bookmark create todo/<name> -r <tail-tip>` |
| 2 | Delete local bookmarks | `jj bookmark delete wip/<suffix> ijcd/<suffix>` |
| 3 | Delete remote branch | `jj git push --deleted -b ijcd/<suffix>` (tolerate "already gone" — GitHub auto-deletes merged heads) |
| 4 | Forget workspace | `jj workspace forget <suffix>` |
| 5 | Remove dir | `rm -rf ~/work/lunar/<suffix>` |
| 6 | Close kitty tab | `kitty @ ls` → match tab `cc:<suffix>` or window `cwd` under the dir → `kitty @ close-tab` |

**Parking stays on `local/main`, not `trunk()`** — rebasing onto `trunk()` would strip the personal base the work sits on (`.envrc`/settings), breaking local dev and conflicting against the base commits. `jj rebase -r <tail> -d local/main` drops the merged-and-squashed middle while keeping the base; `todo/<name>` is then a clean standalone stack resumable exactly like a `wip/*`.

## Safety guards (mandatory, not flags)

- **Denylist**: never touch the `default` or `local-main` workspaces, or the `local/main` bookmark. The base is permanent.
- `rm -rf` refuses unless the path resolves under `~/work/lunar/` **and** contains a `.jj` workspace marker.
- Unconfirmable eligibility (gh/PR/VPN failure) → skip + report, never guess-delete.
- `scan` is read-only; every mutation is behind `teardown` + explicit confirm. `--dry-run` shows the commands.
- Invariant: the skill only ever operates in the `local/main..wip/<suffix>` window; `local/main` and everything below it are untouchable.

## Scope / assumptions

- **`ijcd/<suffix>` head branches only** — `scan` assumes the PR head is `ijcd/<suffix>`. PRs with a different head are out of scope for now.
- lunar workspace convention (`~/work/lunar/<suffix>`) is assumed; prefixes/roots come from `jj-mirror` config so a differently-configured repo mostly works, but the `~/work/lunar` dir root is currently lunar-specific.

## Testing plan

`test/jj-cleanup/` (fixture jj repos, like `test/jj-mirror/`):
- [ ] scan: merged PR → eligible; open PR → not eligible; no-PR/gh-error → skipped with reason
- [ ] lost-commit detection: fully-mirrored+merged → 0 lost; wip ahead of prime → tail counted; uncommitted `@` → counted
- [ ] park: `todo/<name>` created on `local/main`, merged middle dropped, base intact
- [ ] teardown order: park precedes bookmark delete; forget precedes `rm`
- [ ] denylist: refuses `default`/`local-main`/`local/main`
- [ ] `rm -rf` guard: refuses a path outside `~/work/lunar` or without `.jj`
- [ ] remote delete tolerates already-deleted branch
- [ ] `--dry-run` mutates nothing

## What's NOT in this PR

- Non-`ijcd/` head branches.
- Generalizing the `~/work/lunar` dir root beyond lunar.
- Auto-running on merge (git hook / cron) — invocation stays manual.
- Reviving a `todo/<name>` back into a `wip/*` workspace (separate concern; `jj-refresh-workspaces` territory).
