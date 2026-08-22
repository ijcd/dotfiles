# jjflow-guide.sh — long-form, recipe-based help for agents, as a sourced module.
# Emits a stable, greppable doc (MODEL / VERBS / RECIPES with WHEN/DO/VERIFY/WHY)
# so an agent can match its situation and copy exact commands. Pure output — no
# repo needed (an agent may read it before cd-ing into a workspace).

guide_main() {
  case "${1:-}" in
    -h|--help) printf 'jj-flow guide [VERB] — task recipes for the jj-flow ecosystem\n'; return 0 ;;
  esac
  # Optional single-verb filter: `jj-flow guide push` prints just the RECIPE blocks
  # that mention that verb (not the MODEL/VERBS prose). Default: the whole guide.
  local filter="${1:-}"
  if [[ -n "$filter" ]]; then
    awk -v v="$filter" 'BEGIN{RS="\n## "} /^RECIPE/ && $0 ~ v {print "## " $0}' <<<"$(_guide_doc)"
    return 0
  fi
  _guide_doc
}

_guide_doc() {
  cat <<'EOF'
# jj-flow — agent guide

jj-flow maintains your PR stream: messy local work (wip/*) is projected to clean,
stable PR branches (ijcd/*) that never force-push. Each agent works in its own jj
workspace off its own private base, so agents don't collide. `jjf` is the alias.

## MODEL

  master            upstream trunk (moves as colleagues merge)
  local/main        canonical private base = master + your ~7 personal commits
                    (.envrc, pnpm, jj-version fallbacks) — TEMPLATE, don't work on it
  local/main-<W>    YOUR base (per workspace W); a copy of the recipe on master
    wip/<x>         your working branches, off your base
    ijcd/<x>        the PR branch for wip/<x>: your commit base-stripped onto master,
                    advanced APPEND-ONLY (merge-forward) so open PRs never force-push
  local/integration optional octopus of your wip/* for local "test it all" builds

Isolation: catchup + mirror key off your workspace's base (local/main-<W>), so
advancing your stream never touches another agent's base or wip.

## VERBS

  jjf status [--graph]   your stack: per-branch state, PR, drift, base header
  jjf base fork|list     mint/list your per-agent base local/main-<W>
  jjf catchup [-f]       fetch + rebase YOUR base+wip onto trunk; refresh workspaces
  jjf mirror [-n]        re-derive ijcd/* from wip/* (no push); -n = dry-run
  jjf push [-t <br>]     mirror (merge-forward live PRs) + jj-vine submit
  jjf ship               catchup then push, gated on a clean catch-up
  jjf integrate <cmd>    manage local/integration (add/drop/catchup)
  jjf cleanup <name>     retire a merged PR (bookmarks, workspace, dir, tab)
  jjf tug [--all]        advance the nearest bookmark to @-
  jjf guide [VERB]       this guide (or recipes for one verb)

## STATE GLYPHS (jjf status)

  ○ draft   ◐ mirrored   ● live PR   ⚠ stuck (base divergence)   ✓ merged

## RECIPES

## RECIPE 1 — where do I stand
WHEN   starting work, or unsure what needs doing
DO     jjf status --graph
VERIFY reads your base (local/main-<W>), each wip/* state, and a `next` hint line
WHY    the graph is the map; the header's drift tells you if you owe a catchup

## RECIPE 2 — onboard on your own base (DO THIS FIRST, once per workspace)
WHEN   you're a fresh agent and `jjf status` base line reads local/main (shared), not local/main-<W>
DO     cd ~/work/lunar/<your-workspace>
       jjf base fork
VERIFY jjf status        # base line now shows local/main-<your-workspace>
WHY    isolates you: catchup/push then touch only your stream, never the shared base

## RECIPE 3 — start a new PR
WHEN   you have a coherent commit to open as a PR
DO     jj bookmark set wip/<name> -r <the-commit>
       jjf push -t wip/<name>
VERIFY jjf status        # wip/<name> shows ● live with its ijcd/<name> PR
WHY    mirror base-strips your commit onto master as ijcd/<name>; jj-vine opens the PR

## RECIPE 4 — update an open PR without force-pushing
WHEN   you amended/edited a commit behind a live PR, or trunk moved under it
DO     jjf push -t wip/<name>
VERIFY the PR fast-forwards (new commits appended); review comments survive
WHY    a live ijcd/* is advanced APPEND-ONLY (merge-forward), never rewritten — no force-push

## RECIPE 5 — catch up to master (your stream only)
WHEN   `jjf status` header says "N behind → catchup"
DO     jjf catchup            # add -f to also refresh workspaces holding WIP
VERIFY jjf status header reads "✓ current"
WHY    rebases ONLY local/main-<W> + your wip onto new trunk; other agents untouched.
       A conflict rolls back cleanly (nothing rewritten) — resolve, then re-run

## RECIPE 6 — do it all: catch up then push
WHEN   you want your stream current AND your PRs updated in one go
DO     jjf ship
VERIFY catchup runs first; push only happens if catch-up was clean
WHY    gated — a conflicted catch-up stops before any PR update

## RECIPE 7 — a branch is stuck (⚠)
WHEN   jjf status shows ⚠ stuck on a wip/* with a note like "mix.exs — local/main edits it"
DO     read the note under the branch; either fold that file's change into your branch,
       or drop it from your base — then: jjf mirror -n   (dry-run to confirm it clears)
VERIFY the ⚠ becomes ◐/● on the next status
WHY    a base divergence (a file differs between master and your base AND your branch
       touches it) can't byte-match on the PR base; only a base fix clears it, not re-sync

## RECIPE 8 — retire a merged PR
WHEN   a PR merged to master (jjf status shows ✓ merged, or `next` suggests cleanup)
DO     jjf cleanup <name>
VERIFY the wip/ijcd bookmarks, workspace, dir, and tab are gone
WHY    tears down the whole footprint of a finished stream in one step

## RECIPE 9 — test all my wip together locally
WHEN   you want a combined build/test of several wip/* branches
DO     jjf integrate add 'wip/*'
       cd <local/integration workspace> && <build/test>
VERIFY local/integration is an octopus merge of your selected wip
WHY    local-only, disposable; never pushed

## NEVER

  - NEVER `jjf catchup` (or any rebase) on the shared `local/main` — it drags every
    agent. Work off your own local/main-<W> (RECIPE 2).
  - NEVER move another agent's base or wip.
  - NEVER edit an `ijcd/*` PR commit by hand — mirror owns it; next sync overwrites.
  - If unsure, `jjf status --graph` first; it tells you what's safe to do.
EOF
}
