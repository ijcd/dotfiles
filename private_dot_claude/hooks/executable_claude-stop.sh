#!/bin/bash
# Claude Stop / Notification hook: ring bell + set the waiting indicator (⏳).
# Stop = turn complete. Notification = needs attention mid-turn (perm prompts).
# Both mean "look at me." Strips any prior indicator (⏳ or …) before prepending ⏳.

# 1) ring bell (works in any terminal with a tty)
printf '\a' > /dev/tty 2>/dev/null

# 2) update kitty tab title if remote control is available
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

# already showing waiting indicator? skip
[[ "⏳ $base" == "$cur" ]] && exit 0

kitty @ set-tab-title --match "window_id:$KITTY_WINDOW_ID" "⏳ $base" 2>/dev/null
