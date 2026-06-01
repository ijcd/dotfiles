#!/bin/bash

# Kitchen sink status line - shows all available data
input=$(cat)

# Extract all data points
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
model_id=$(echo "$input" | jq -r '.model.id // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
session=$(echo "$input" | jq -r '.session_id // empty')
output_style=$(echo "$input" | jq -r '.output_style.name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# Git branch (skip locks)
branch=""
if [ -d "$cwd/.git" ]; then
  cd "$cwd" 2>/dev/null
  branch=$(git -c core.fileMode=false symbolic-ref --short HEAD 2>/dev/null || git -c core.fileMode=false rev-parse --short HEAD 2>/dev/null)
fi

# Directory name (short)
dir_name=$(basename "$cwd")

# Session ID truncated (first 8 chars)
session_short=$(echo "$session" | cut -c1-8)

# Calculate cost (Claude 3.5 Sonnet pricing: $3/MTok input, $15/MTok output)
cost=""
if [ "$total_in" -gt 0 ] || [ "$total_out" -gt 0 ]; then
  # Calculate in cents then convert to dollars
  cost_cents=$(echo "scale=2; ($total_in * 3 + $total_out * 15) / 1000000" | bc 2>/dev/null || echo "0")
  cost="\$${cost_cents}"
fi

# Git stats (lines added/removed in session)
lines_stats=""
if [ -d "$cwd/.git" ]; then
  cd "$cwd" 2>/dev/null
  stats=$(git -c core.fileMode=false diff --shortstat HEAD 2>/dev/null)
  if [ -n "$stats" ]; then
    added=$(echo "$stats" | grep -o '[0-9]\+ insertion' | grep -o '[0-9]\+')
    removed=$(echo "$stats" | grep -o '[0-9]\+ deletion' | grep -o '[0-9]\+')
    [ -n "$added" ] && lines_stats="+$added"
    [ -n "$removed" ] && lines_stats="${lines_stats}-$removed"
  fi
fi

# Extract model version from ID (e.g., claude-3-5-sonnet-20241022 -> 20241022)
model_version=""
if [ -n "$model_id" ]; then
  model_version=$(echo "$model_id" | grep -o '[0-9]\{8\}$' || echo "")
fi

# Build status line parts
parts=()

# Model with version
if [ -n "$model_name" ]; then
  if [ -n "$model_version" ]; then
    parts+=("$model_name ($model_version)")
  else
    parts+=("$model_name")
  fi
fi

# Directory and branch
if [ -n "$dir_name" ]; then
  if [ -n "$branch" ]; then
    parts+=("$dir_name@$branch")
  else
    parts+=("$dir_name")
  fi
fi

# Cost
[ -n "$cost" ] && [ "$cost" != "\$0" ] && parts+=("$cost")

# Lines changed
[ -n "$lines_stats" ] && parts+=("$lines_stats")

# Context percentage with warning
if [ -n "$used_pct" ]; then
  ctx_str="ctx:${used_pct}%"
  used_int=$(echo "$used_pct" | cut -d. -f1)
  [ "$used_int" -ge 80 ] && ctx_str="$ctx_str⚠"
  [ "$used_int" -ge 95 ] && ctx_str="$ctx_str!"
  parts+=("$ctx_str")
fi

# Token counts (in thousands)
if [ "$total_in" -gt 0 ]; then
  tok_in=$(echo "scale=0; $total_in / 1000" | bc)
  parts+=("in:${tok_in}k")
fi
if [ "$total_out" -gt 0 ]; then
  tok_out=$(echo "scale=0; $total_out / 1000" | bc)
  parts+=("out:${tok_out}k")
fi

# Output style
[ -n "$output_style" ] && [ "$output_style" != "default" ] && parts+=("style:$output_style")

# Session ID
[ -n "$session_short" ] && parts+=("id:$session_short")

# Join with separator
IFS=' | '
echo "${parts[*]}"

# ─── Kitty tab rendering (broad mode: busy=🟡, idle=🔴) ───
# Statusline runs on every Claude Code UI update, so this is effectively a live
# state monitor. We read .status from ~/.claude/sessions/<pid>.json (matched by
# sessionId) and reflect it on the kitty tab — title prefix + tab background tint.
# A small state-cache file avoids redundant kitty @ calls when nothing changed.

if [ -n "${KITTY_LISTEN_ON:-}" ] && [ -n "${KITTY_WINDOW_ID:-}" ] && [ -n "$session" ]; then
    # Live session status; falls back to "unknown" for older Claude versions or fresh sessions.
    status=$(jq -r --arg sid "$session" 'select(.sessionId == $sid) | .status // "unknown"' \
                ~/.claude/sessions/*.json 2>/dev/null | head -1)
    [ -z "$status" ] && status="unknown"

    # Saturated bg in the state's hue; active fg is white (high-contrast for the
    # focused tab where you're reading), inactive fg is a dim shade of the ball
    # color (state-coded for peripheral scanning of unfocused tabs).
    case "$status" in
        busy) emoji="🟡"; active_bg="#5e4818"; inactive_bg="#3e3008"; active_fg="#ffffff"; inactive_fg="#cc9030" ;;
        idle) emoji="🔴"; active_bg="#5e2424"; inactive_bg="#3e1818"; active_fg="#ffffff"; inactive_fg="#cc4040" ;;
        *)    emoji="" ;;  # status field missing (older Claude Code) — leave tab unchanged
    esac

    if [ -n "$emoji" ]; then
        # Cache last-applied state to skip redundant kitty calls on every render.
        # Key includes all colors so editing the palette auto-invalidates the cache
        # — otherwise a color tweak with the same emoji wouldn't re-render.
        state_file="/tmp/claude-tabstate-${session}"
        state_key="${emoji}|${active_bg}|${inactive_bg}|${active_fg}|${inactive_fg}"
        if [ "$state_key" != "$(cat "$state_file" 2>/dev/null)" ]; then
            echo "$state_key" > "$state_file"

            cur=$(kitty @ ls 2>/dev/null | jq -r --argjson wid "$KITTY_WINDOW_ID" \
                  '.[].tabs[] | select(.windows[].id == $wid) | .title' 2>/dev/null)
            # strip any leading status prefix (current + legacy markers)
            base="$cur"
            base="${base#🟢 }"; base="${base#🟡 }"; base="${base#🔴 }"
            base="${base#⏳ }"; base="${base#… }"

            kitty @ set-tab-title --match "window_id:$KITTY_WINDOW_ID" "$emoji $base" 2>/dev/null
            kitty @ set-tab-color --match "window_id:$KITTY_WINDOW_ID" \
                active_bg="$active_bg" inactive_bg="$inactive_bg" \
                active_fg="$active_fg" inactive_fg="$inactive_fg" 2>/dev/null
        fi
    fi
fi
