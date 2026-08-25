#!/bin/bash
# claude-attn.sh set|clear — mark/unmark this Claude session as "waiting on input".
# Claude Code's native .status is only busy/idle/shell — there's no "waiting"
# value — so we derive it from the Notification hook (fires on permission prompts
# / idle-waiting) and let statusline.sh tint the kitty tab distinctly:
#   🟡 busy   🔵 waiting on you   🔴 idle/done
# Keyed on session_id, the same id statusline reads from its own stdin.
mode="${1:-set}"
sid=$(jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
marker="/tmp/claude-attn-$sid"
case "$mode" in
  set)   : > "$marker" ;;
  clear) rm -f "$marker" ;;
esac
exit 0
