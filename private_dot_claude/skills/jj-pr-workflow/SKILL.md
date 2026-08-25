---
name: jj-pr-workflow
description: Use when creating, updating, splitting, or shipping a GitHub PR in a jj (jujutsu) repo that uses jj-flow (jjf) — e.g. lunar — where each agent works off its own per-workspace base local/main-<workspace> and wip/* branches mirror to ijcd/* PR branches (append-only, no force-push). Covers onboarding onto your base, catch-up, and scoping a push to one branch. For the full recipe set run `jjf guide`.
---

# Shipping PRs with jj-flow (jjf)

One command: `jjf` (`jj-flow`). **Run `jjf guide` first** — it prints task recipes
(WHEN/DO/VERIFY/WHY) for the whole workflow. This skill is the mistakes-to-avoid layer.

Two-sided, per-agent model. Conflating the sides is the #1 mistake.

- **Source side (private, per-agent).** Each agent = a jj workspace with its OWN base
  `local/main-<workspace>` (your ~7 personal commits on master: env setup, jj fallbacks).
  **Never pushed; its commits never appear in any PR.** Feature work goes on `wip/<name>`
  stacked on YOUR base. The canonical `local/main` is a template — nobody works on it.
- **Prime side (published).** `jjf mirror` replays each `wip/<name>` thread onto master,
  stripping your base, into a machine-managed `ijcd/<name>` bookmark; `jjf push` also
  submits/updates the PR via jj-vine. A live PR is advanced **append-only (merge-forward)**
  — it never force-pushes, so review comments survive.

```
wip/foo   ● your commits              ijcd/foo ● same commits, on master
          │ on local/main-<W>  ──▶             │ base stripped, merge-forward
local/main-<W> ● never pushed         master  ●
```

## Critical rules

- **Onboard first:** `jjf base fork` once per workspace to mint `local/main-<W>`. Then
  everything you do touches only your stream. `jjf status` should show your base.
- **NEVER `jjf catchup`/rebase the shared `local/main`** — it drags every other agent.
  Catch up your own base: `jjf catchup` (it rebases only `local/main-<W>` + your wip).
- **Put work on `wip/<name>`, never on `ijcd/<name>`.** `ijcd/*` is machine-owned; a
  next `jjf mirror` overwrites a hand-made one.
- **Your base is never pushed or incorporated.** Don't rebase work off it to "clean up" a
  PR, don't hand-exclude its commits — mirror strips everything below your base.
- **Scope a push to one branch:** `jjf push -t wip/<name>`. The `-t` also skips the
  orphan-cull so other threads' primes aren't touched. Preview: `jjf mirror -n`.

## Recipes

**Onboard (once)** — `cd ~/work/lunar/<workspace>` ; `jjf base fork`

**New feature → PR**
```
jj bookmark set wip/<name> -r <your-tip>
jjf push -t wip/<name>        # mirror-forward onto master + open the (draft) PR
```

**Update an existing PR** (more commits / edits on `wip/<name>`)
```
jjf push -t wip/<name>        # advances the live PR APPEND-ONLY — no force-push
```

**Catch up to latest trunk** (your stream only)
```
jjf catchup                   # -f also refreshes WIP workspaces; -c validates paths only
```

**Split one branch into two PRs** (independent siblings)
```
jj rebase -r <second-commit> -d local/main-<W>   # sibling off YOUR base, not stacked
jj bookmark set wip/<other> -r <first-commit>
jjf push -t wip/<name> ; jjf push -t wip/<other>
```
Only valid if the two commits are independent; if the upper depends on the lower, keep
them one PR or stack them.

## After submitting

- jj-vine opens PRs as **draft**, titled after the bookmark, **no body**. Set them:
  `gh pr edit <N> --title "…" --body-file <file>`.
- **Copilot review:** `--add-reviewer @copilot` fails (it's a bot); use the PR web UI's
  "Request Copilot review" if enabled.
- **Commit messages:** no "Generated with Claude Code" / `Co-Authored-By` (global rule).

## Related

- `jjf status [--graph]` — your stack: per-branch state, PR, drift, base header.
- `jjf base fork|list` · `jjf tug [--all]` · `jjf integrate {add|drop|catchup}` · `jjf cleanup <name>`.
- `jjf mirror {status|add|rm|config}` — inspect/manage mirror rules.
- `jjf guide` — the full recipe doc (source of truth for the workflow).

## Notes

Grounded in real execution: agents hand-created `ijcd/*` bookmarks, rebased work off the
base to exclude commits, and ran catch-up on the shared `local/main` — all wrong. The
per-agent base + `jjf` verbs prevent the last one structurally.
