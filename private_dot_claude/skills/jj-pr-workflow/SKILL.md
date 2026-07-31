---
name: jj-pr-workflow
description: Use when creating, updating, splitting, or shipping a GitHub PR in a jj (jujutsu) repo that uses the jj-mirror + jj-vine toolchain (e.g. lunar) — where local/main is a permanent local-only base and wip/* branches mirror to ijcd/* PR branches. Covers ranch/eaddrinuse-adjacent workflow, catch-up, and scoping a push to one branch.
---

# Shipping PRs in a jj-mirror + jj-vine repo

Two-sided model. Conflating the sides is the #1 mistake.

- **Source side** — `local/main` is a PERMANENT local-only base holding personal commits (local settings, env setup, jj fallbacks). **Never pushed; its commits never appear in any PR.** Feature work goes on `wip/<name>` bookmarks stacked on `local/main`.
- **Prime side** — `jj-mirror` replays each `wip/<name>` thread (only `local/main..tip`) onto `master`, stripping the `local/main` base, into a **machine-managed** `ijcd/<name>` bookmark. `jj-vine` pushes those and opens/updates the PRs.

```
wip/foo   ● your commits              ijcd/foo ● same commits, on master
          │ on local/main   ──mirror──▶         │ local/main stripped
local/main ● never pushed             master  ●
```

## Critical rules (the actual mistakes to avoid)

- **Put work on `wip/<name>`, never on `ijcd/<name>`.** `ijcd/*` is the prime prefix — jj-mirror creates and owns it. Hand-making an `ijcd/` bookmark fights the tool.
- **`local/main` is never pushed and never incorporated.** Don't rebase your work off it to "clean up" a PR, and don't hand-exclude its commits — jj-mirror already strips everything below `local/main`.
- **`jj-mirror push` is REPO-WIDE** (syncs every thread, submits every prime). To act on ONE branch: `jj-mirror sync -t wip/<name>` then `jj-vine submit ijcd/<name>`. The `-t` also skips the orphan-cull, so other threads' primes aren't deleted.
- **Preview before mutating:** `jj-mirror sync -t wip/<name> --dry-run` and `jj-vine submit -r ijcd/<name> --dry-run`.

## Recipes

**New feature → PR**
```
jj bookmark create wip/<name> -r <your-tip>
jj-mirror sync -t wip/<name>          # derives ijcd/<name> on master
jj-vine submit ijcd/<name>            # pushes + opens the (draft) PR
```

**Update an existing PR** (after more commits on `wip/<name>`)
```
jj-mirror sync -t wip/<name>
jj-vine submit ijcd/<name>
```

**Split one branch into two PRs** (stacked commits → independent siblings)
```
jj rebase -r <second-commit> -d local/main     # sibling off local/main, not stacked
jj bookmark create wip/<other> -r <first-commit>
jj-mirror sync -t wip/<name>  ;  jj-mirror sync -t wip/<other>
jj-vine submit ijcd/<name>    ;  jj-vine submit ijcd/<other>
```
Only valid if the two commits are independent. If the upper depends on the lower, split PRs each fail CI alone — keep them as one PR, or base the upper's PR on the lower's branch (a stacked PR, not a split).

**Catch up to latest trunk** (fetch master, restack `local/main` + branches onto it, refresh workspaces)
```
jj-catch-up          # -f also refreshes WIP workspaces; -c validates workspace paths only
```

## After submitting

- jj-vine has `openAsDraft=true` and `description.sync=false`: PRs open as **draft**, titled after the bookmark, with **no body**. Set a real title/body: `gh pr edit <N> --title "…" --body-file <file>`.
- **Copilot review:** `gh pr edit --add-reviewer @copilot` fails ("could not resolve user" — it's a bot). Only requestable if the repo has Copilot code review enabled (check `suggestedActors` via GraphQL); otherwise use the PR web UI's "Request Copilot review".
- **Commit messages:** no "Generated with Claude Code" / `Co-Authored-By` lines (user global rule).

## Related tools

- `jj-tug [--all] [glob]` — advance the nearest bookmark up to `@-`.
- `jj-integrate {add|drop|catchup}` — octopus-merge a persistent SET of branches into `local/integration` for combined local testing.
- `jj-mirror {config|list|status}` — inspect prefixes, rules, per-thread ok/stale/missing.
- Design spec: `docs/superpowers/specs/2026-07-15-jj-mirror-design.md` (in repos that vendor it).

## Notes

Grounded in real execution: without this, an agent hand-created an `ijcd/*` bookmark, tried to rebase work off `local/main` to exclude its commits, and nearly ran the repo-wide `jj-mirror push` — all three are wrong. Not yet subagent-pressure-tested.
