#!/bin/bash
# Claude UserPromptSubmit hook: claude is now working, set the working indicator (…).
# Strips any prior indicator (⏳ or …) before prepending …, so the prefix never doubles.

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

# strip any leading status prefix
base="$cur"
base="${base#⏳ }"
base="${base#… }"

# already showing working indicator? skip
[[ "… $base" == "$cur" ]] && exit 0

kitty @ set-tab-title --match "window_id:$KITTY_WINDOW_ID" "… $base" 2>/dev/null
