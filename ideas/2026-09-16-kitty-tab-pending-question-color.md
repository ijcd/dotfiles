# QUEUED — kitty tab: a reliable distinct color for "pending question"

**Requested:** 2026-09-16, right after the jjf-catchup-targeted-scope work. Do this NEXT (queued behind that build).

## Want

A pending question/input state (permission prompt, `AskUserQuestion`, idle-waiting-on-you)
must tint the kitty tab a color that is **neither red nor yellow**. Today busy AND
questioning both read yellow — indistinguishable. Blue was attempted but "only works in
certain cases." Make the distinct color fire for **every** pending-input case, robustly —
including `AskUserQuestion` (structured questions), which is the case that visibly fails.

**Observed failure (screenshot 2026-09-16 2:27pm):** an active `AskUserQuestion` prompt —
tab `cc:controlled-s…` — shows 🟡 **yellow (busy)**, not blue. So the "waiting" state is
not being detected for structured questions.

## Why blue is flaky (current mechanism)

"waiting" is not a native Claude Code status — native `.status` is only busy/idle/shell
(`private_dot_claude/hooks/executable_claude-attn.sh:2-6`). Blue is **derived**:

1. `Notification` hook → `claude-attn.sh set` drops `/tmp/claude-attn-<session>`
   (`executable_claude-attn.sh:11-14`).
2. `executable_statusline.sh:129-134` promotes status→`waiting` **only if** the marker
   exists AND status is still busy (not idle/shell/unknown — those clear the marker at
   `:130-131` so an exited tab never sticks blue).
3. `:141` paints waiting = 🔵 `#1e3a5e`.

**Two failure modes in that chain:**
- **`AskUserQuestion` doesn't fire the `Notification` hook** → no marker → stays 🟡 busy.
  (Commit `4ba96cd` tried to make AskUserQuestion set the marker; screenshot shows it's
  still not landing — verify that hook wiring in `settings.json` actually fires on the
  structured-question path.)
- **Busy-gate coupling** (`:130`): blue only shows while status==busy. If the question
  arrives as the turn goes idle, the marker is cleared and it falls to 🔴 red instead.

## The likely real fix (not yet designed — brainstorm first)

The derive-via-marker + busy-gate approach is the fragility. Options to explore:
- **Drive the marker from the actual pending-input events**, not just `Notification`: wire
  every prompt path (permission prompt, `AskUserQuestion`, idle notification) to
  `claude-attn.sh set`, and clear on `UserPromptSubmit`/`Stop`. Audit which hook events
  Claude Code actually emits for `AskUserQuestion` — that's the crux (may be none, in
  which case the statusline must infer "waiting" another way).
- **Decouple blue from the busy-gate**: let the marker alone mean waiting regardless of
  busy/idle, with a robust clear-on-answer so it can't stick.
- Confirm the color is distinct enough at a glance from both 🟡 and 🔴 (the blue
  `#1e3a5e` is fine if it actually fires).

## Files

- `private_dot_claude/executable_statusline.sh:118-168` — the state→color logic + kitty
  `set-tab-color` call.
- `private_dot_claude/hooks/executable_claude-attn.sh` — set/clear the waiting marker.
- `private_dot_claude/hooks/executable_claude-stop.sh` — Stop/Notification/SessionStart bell hook.
- `private_dot_claude/settings.json` — hook event wiring (which events call attn set/clear).
- `dot_config/kitty/kitty.conf` — tab bar config.

## Prior art (commits on this exact problem)

- `5ef55c1` kitty tab shows blue "waiting on input" (distinct from busy)
- `f9a1ba5` statusline: read sessions from `$CLAUDE_CONFIG_DIR`; blue only when busy-blocked
- `4ba96cd` AskUserQuestion sets the blue "waiting" marker (structured questions don't fire Notification)

The screenshot proves `4ba96cd` didn't fully land — start there.

## Note

`ideas/` is chezmoi-ignored (`.chezmoiignore`) — tracked in git, not deployed. After the
real fix, changes to `private_dot_claude/**` need `chezmoi apply` to reach `~/.claude/`.
