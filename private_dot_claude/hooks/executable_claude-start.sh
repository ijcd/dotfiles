#!/bin/bash
# Claude UserPromptSubmit hook: strip ⏳ prefix added by claude-stop.sh.

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
    "⏳ "*) kitty @ set-tab-title --match "window_id:$KITTY_WINDOW_ID" "${cur#⏳ }" 2>/dev/null ;;
esac
