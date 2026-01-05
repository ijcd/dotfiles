# Keybinding utilities - tracing and display
#
# Usage:
#   bindkey_dump              # Raw dump of all keymaps (for debugging)
#   show_keybindings          # Formatted display of main keymap (user-facing)
#   ztrace_source /path/file  # Show keybinding changes from sourcing a file
#   ztrace_zim_init           # Show keybinding changes from Zim init

# Raw dump of all keymaps (for debugging)
bindkey_dump() {
  for map in $(bindkey -l); do
    echo "=== KEYMAP: $map ==="
    bindkey -M $map
    echo
  done
}

# Source a file and show keybinding changes
ztrace_source() {
  local file=$1
  echo "=====================================================================" >&2
  echo "ztrace: $file" >&2

  typeset -A _ztrace_before _ztrace_after

  # Capture before
  for map in $(bindkey -l); do
    _ztrace_before[$map]=$(bindkey -M $map)
  done

  # Source the file
  source "$file"

  # Capture after
  for map in $(bindkey -l); do
    _ztrace_after[$map]=$(bindkey -M $map)
  done

  # Show diffs
  local has_changes=0
  for map in $(bindkey -l); do
    if ! diff -q <(echo ${_ztrace_before[$map]}) <(echo ${_ztrace_after[$map]}) >/dev/null 2>&1; then
      has_changes=1
      echo "---------------------------------------" >&2
      echo "KEYMAP=$map" >&2
      diff -u <(echo ${_ztrace_before[$map]}) <(echo ${_ztrace_after[$map]}) | grep -E '^(\+|-)\"' >&2
    fi
  done

  (( has_changes == 0 )) && echo "(no keybinding changes)" >&2
}

# Wrapper for Zim init - shows keybinding changes from all modules
ztrace_zim_init() {
  ztrace_source "${ZIM_HOME}/init.zsh"
}

# Display formatted list of current keybindings from main keymap
show_keybindings() {
  echo "Current Keybindings (main keymap):"
  echo "─────────────────────────────────────────"
  bindkey -M main | while read -r key func; do
    # Make control chars readable
    local readable_key=$key
    readable_key=${readable_key//\^\[/Alt-}
    readable_key=${readable_key//\^/Ctrl-}
    printf "  %-20s %s\n" "$readable_key" "$func"
  done | sort
}
