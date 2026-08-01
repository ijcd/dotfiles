---
name: jj-pr-cleanup
description: Use when a lunar PR is closed/merged to master and you want to tear down its leftovers — local + remote bookmarks, the jj workspace, its directory, and its kitty tab — parking any unmerged work under todo/<name> first. Wraps the tested `jj-cleanup` tool; always confirms before mutating.
---

# jj-pr-cleanup

Tear down what a merged/closed PR leaves behind, safely. Backed by the tested
`jj-cleanup` tool (`~/.local/bin/jj-cleanup`). Model: `wip/<suffix>` on
`local/main` → mirror → `ijcd/<suffix>` PR branch → workspace `~/work/lunar/<suffix>`,
kitty tab `cc:<suffix>`. `local/main` and the `default`/`local-main` workspaces
are never touched.

## Steps

1. **Scan (read-only).** Run `jj-cleanup scan --fetch`. It fetches, then prints
   one row per workspace: `SUFFIX  PR  IJCD  LOST  TAB`.
   - `PR` = MERGED / CLOSED / OPEN / NONE / ERROR (from `gh`).
   - `LOST` = commits on `wip/<suffix>` beyond what the PR contained (unmerged
     tail), `+dirty` if the workspace has uncommitted changes.

2. **Pick.** Eligible = `PR` is **MERGED or CLOSED**. Never propose OPEN / NONE /
   ERROR rows. Present the candidates to the user as a short table.

3. **Name the parks.** For any candidate with `LOST > 0` (or `+dirty`), propose a
   descriptive `todo/<name>` (e.g. `todo/vault-hoist-retry`) — this is where the
   unmerged tail is preserved. Rows with `LOST 0` need no `--park`.

4. **Dry-run + confirm.** For each pick, run
   `jj-cleanup teardown <suffix> [--park todo/<name>] --dry-run` and show the exact
   commands. **Get explicit go/no-go from the user before mutating.**

5. **Execute.** On approval, run `jj-cleanup teardown <suffix> [--park todo/<name>]`
   per pick. Report what was deleted and where each park landed.

## Rules

- Confirm before any real teardown. Scan and `--dry-run` never mutate.
- One workspace per `teardown` call; loop over the user's picks.
- If a row is ERROR/NONE (gh failed, VPN down, no PR), **skip it and say why** —
  never guess-delete.
- `+dirty` means uncommitted work in the workspace `@`; always `--park` those.
- Parks land on `local/main`, resumable exactly like a `wip/*`.
