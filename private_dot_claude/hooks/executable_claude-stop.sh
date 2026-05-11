#!/bin/bash
# Claude bell hook for Stop / Notification / SessionStart events.
# Audio-only — all visual tab state (title + color) is rendered by statusline.sh,
# which runs on every Claude Code UI update.

{ printf '\a' > /dev/tty; } 2>/dev/null
exit 0
