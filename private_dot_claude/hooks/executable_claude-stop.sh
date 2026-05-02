#!/bin/bash
# Claude Stop hook: ring bell + prepend ⏳ to the kitty tab title.
# Persists until UserPromptSubmit fires (claude-start.sh) which strips ⏳.

# 1) ring bell (works everywhere with a TTY, including kitty)
printf '\a' > /dev/tty 2>/dev/null

# 2) if running inside a kitty with remote control, prepend ⏳ to the tab title
[ -n "$KITTY_LISTEN_ON" ] && [ -n "$KITTY_WINDOW_ID" ] || exit 0

cur=$(kitty @ ls 2>/dev/null | /usr/bin/python3 -c '
import sys, json, os
try:
    wid = int(os.environ["KITTY_WINDOW_ID"])
    data = json.load(sys.stdin)
    for os_window in data:
        for tab in os_window.get("tabs", []):
            for win in tab.get("windows", []):
                if win.get("id") == wid:
                    print(tab.get("title", ""))
                    sys.exit(0)
except Exception:
    pass
')

case "$cur" in
    "⏳ "*) ;;  # already waiting, don't double up
    *) kitty @ set-tab-title --match "window_id:$KITTY_WINDOW_ID" "⏳ $cur" 2>/dev/null ;;
esac
