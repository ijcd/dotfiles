#!/bin/bash
# claude-attn.sh set|clear — mark/unmark this Claude session as "waiting on input", then
# repaint its kitty tab IMMEDIATELY. Claude Code's native .status is only busy/idle/shell
# (no "waiting"), so we derive waiting from a marker file that the Notification and
# PreToolUse[AskUserQuestion] hooks drop. Claude Code does NOT re-run the statusline while
# a blocking modal is open (verified 2026-09-16), so THIS hook must trigger the repaint —
# it calls the same resolver statusline uses. Keyed on session_id, the id statusline matches.
#   🟡 busy   🔵 waiting on you   🔴 idle/done
mode="${1:-set}"
sid=$(jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
marker="/tmp/claude-attn-$sid"
case "$mode" in
  set)   : > "$marker" ;;
  clear) rm -f "$marker" ;;
esac
# Repaint now — the statusline won't run during the modal. The resolver re-derives state
# (marker + .status) and is cache-guarded, so a busy/idle session paints correctly too.
source "$(dirname "${BASH_SOURCE[0]}")/kitty-tab-lib.sh" 2>/dev/null && kitty_tab_paint "$sid"
exit 0
