#!/bin/bash
# kitty-tab-lib.sh — shared kitty-tab state paint for statusline.sh + claude-attn.sh.
# SOURCED, not executed. Single source of truth for mapping a session's live state
# (busy / waiting-on-you / idle) to the kitty tab's title-emoji + background tint.
#
# WHY shared (the AskUserQuestion bug): statusline.sh paints on every Claude Code UI
# render, but Claude Code does NOT re-invoke the statusline while a blocking modal
# (AskUserQuestion / permission prompt) is open — verified 2026-09-16: the Notification
# and PreToolUse[AskUserQuestion] hooks DO set the /tmp/claude-attn-<session> marker at
# modal-open, but zero statusline renders happen during the modal, so the marker is never
# read into a repaint and the tab stays frozen on its pre-modal (busy/🟡) render. The fix:
# claude-attn.sh calls THIS same resolver right after it sets/clears the marker, so the
# tab repaints the instant the state changes — the hook is the only thing that runs at
# modal-open. Idempotent + cache-guarded, so calling it from both places is safe.

# kitty_tab_paint SESSION — resolve SESSION's state and paint its kitty tab. No-op unless
# running inside kitty (KITTY_LISTEN_ON + KITTY_WINDOW_ID) with a non-empty SESSION.
kitty_tab_paint() {
  local session="$1"
  [ -n "${KITTY_LISTEN_ON:-}" ] && [ -n "${KITTY_WINDOW_ID:-}" ] && [ -n "$session" ] || return 0

  # Live session status; falls back to "unknown" for older Claude versions or fresh
  # sessions. Sessions live under CLAUDE_CONFIG_DIR (which may differ from where these
  # scripts are installed), so resolve state there — NOT relative to this file.
  local status
  status=$(jq -r --arg sid "$session" 'select(.sessionId == $sid) | .status // "unknown"' \
              "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/sessions/*.json 2>/dev/null | head -1)
  [ -z "$status" ] && status="unknown"

  # "waiting on input" is not a native status (Claude Code emits only busy/idle/shell);
  # the Notification / PreToolUse hooks drop /tmp/claude-attn-<session>. Blue ONLY
  # overrides an ACTIVE (busy) session that's blocked; once idle the turn is over — red
  # wins and we clear any stale marker, so finishing never leaves a tab stuck blue.
  local attn="/tmp/claude-attn-${session}"
  if [ "$status" = idle ] || [ "$status" = shell ] || [ "$status" = unknown ]; then
    rm -f "$attn"
  elif [ -f "$attn" ]; then
    status="waiting"
  fi

  # Saturated bg in the state's hue; active fg white (focused tab you're reading),
  # inactive fg a dim shade of the ball color (peripheral scanning of unfocused tabs).
  local emoji active_bg inactive_bg active_fg inactive_fg
  case "$status" in
    busy)    emoji="🟡"; active_bg="#5e4818"; inactive_bg="#3e3008"; active_fg="#ffffff"; inactive_fg="#cc9030" ;;
    waiting) emoji="🔵"; active_bg="#1e3a5e"; inactive_bg="#14283e"; active_fg="#ffffff"; inactive_fg="#5a9fd4" ;;
    idle)    emoji="🔴"; active_bg="#5e2424"; inactive_bg="#3e1818"; active_fg="#ffffff"; inactive_fg="#cc4040" ;;
    *)       return 0 ;;  # status field missing (older Claude Code) — leave tab unchanged
  esac

  # Cache last-applied state to skip redundant kitty @ calls. Key includes all colors so
  # a palette edit auto-invalidates the cache.
  local state_file="/tmp/claude-tabstate-${session}"
  local state_key="${emoji}|${active_bg}|${inactive_bg}|${active_fg}|${inactive_fg}"
  [ "$state_key" = "$(cat "$state_file" 2>/dev/null)" ] && return 0
  echo "$state_key" > "$state_file"

  local cur base
  cur=$(kitty @ ls 2>/dev/null | jq -r --argjson wid "$KITTY_WINDOW_ID" \
        '.[].tabs[] | select(.windows[].id == $wid) | .title' 2>/dev/null)
  # strip any leading status prefix (current + legacy markers)
  base="$cur"
  base="${base#🟡 }"; base="${base#🔴 }"; base="${base#🔵 }"; base="${base#🟢 }"
  base="${base#⏳ }"; base="${base#… }"

  kitty @ set-tab-title --match "window_id:$KITTY_WINDOW_ID" "$emoji $base" 2>/dev/null
  kitty @ set-tab-color --match "window_id:$KITTY_WINDOW_ID" \
      active_bg="$active_bg" inactive_bg="$inactive_bg" \
      active_fg="$active_fg" inactive_fg="$inactive_fg" 2>/dev/null
}
