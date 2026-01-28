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
