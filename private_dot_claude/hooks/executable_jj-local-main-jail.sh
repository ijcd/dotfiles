#!/usr/bin/env bash
# PreToolUse(Bash) — jj-flow "local/main jail".
#
# ASK before any jj/jjf command that names the SHARED bare `local/main` bookmark
# together with a mutating verb (rebase/new/edit/bookmark/catchup/mirror/…). The
# shared local/main is a template every agent's base forks from — rebasing, moving,
# or landing @ on it drags every other agent. Approving is a deliberate "yes, I mean
# vanilla local/main work"; denying catches an agent drifting onto it.
#
# PASSES silently (exit 0) for: non-jj commands, pure reads, and anything that names
# a per-workspace base (local/main-<W>) or wip/* — those are always safe.
set -uo pipefail

cmd="$(cat | jq -r '.tool_input.command // empty')"
[ -n "$cmd" ] || exit 0

# Only engage on jj / jjf / jj-flow commands.
case "$cmd" in
  *"jj "*|*"jjf "*|*"jj-flow "*) ;;
  *) exit 0 ;;
esac

# Does it name the BARE shared local/main? (word-boundary: local/main-<W> is exempt
# since the next char is "-"; local/main* is a family glob, exempt via "*".)
printf '%s' "$cmd" | grep -qE 'local/main($|[^-*A-Za-z0-9_])' || exit 0

# It names bare local/main. Only ASK when a MUTATING verb is present — reads
# (jj log -r local/main, show, status, diff, op, `bookmark list`) pass untouched.
# Two shapes: a bare mutating jj verb, or `bookmark` + a MUTATING subcommand
# (list is a read → exempt; that's the bit that used to false-fire).
bare_mut='rebase|new|edit|abandon|squash|restore|describe|commit|split|absorb|duplicate|catchup|mirror|ship|tug|integrate'
bmk_mut='(^|[^A-Za-z0-9_])bookmark[[:space:]]+(create|set|move|rename|delete|forget|track|untrack)'
if printf '%s' "$cmd" | grep -qwE "($bare_mut)" \
   || printf '%s' "$cmd" | grep -qE "$bmk_mut"; then
  jq -n --arg r 'jj-flow local/main JAIL — this command touches the SHARED local/main bookmark. Never rebase/move/catchup/land-@ on it: it is the template every agent forks from and mutating it drags every other agent. APPROVE only if you deliberately mean vanilla work on shared local/main; otherwise DENY and use your per-workspace base local/main-<workspace> or a wip/* branch.' \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
fi
exit 0
