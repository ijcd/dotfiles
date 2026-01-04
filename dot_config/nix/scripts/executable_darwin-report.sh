#!/usr/bin/env bash
#
# Improved darwin-preview.sh
# Build a new nix-darwin system and show what will change before switching.

set -euo pipefail

if ! command -v darwin-rebuild >/dev/null 2>&1; then
  echo "Error: darwin-rebuild not found. Ensure Nix paths are loaded." >&2
  exit 1
fi

echo "== Building new nix-darwin configuration =="
darwin-rebuild build "$@"

NEW="./result"
OLD="/run/current-system"

echo
echo "== System profiles =="
echo "Old: $OLD"
echo "New: $NEW"

###############################################################################
# Safe recursive diff
###############################################################################
safe_diff() {
  local title="$1"
  local a="$2"
  local b="$3"

  echo
  echo "== Diff: $title =="
  if [[ -d "$a" && -d "$b" ]]; then
    diff -ruN "$a" "$b" || true
  else
    echo "One side missing:"
    echo "  $a: $( [ -d "$a" ] && echo exists || echo missing )"
    echo "  $b: $( [ -d "$b" ] && echo exists || echo missing )"
  fi
}

safe_diff "/etc (managed by nix-darwin)" \
  "$OLD/etc" "$NEW/etc"

safe_diff "LaunchDaemons" \
  "$OLD/Library/LaunchDaemons" "$NEW/Library/LaunchDaemons"

safe_diff "LaunchAgents" \
  "$OLD/Library/LaunchAgents" "$NEW/Library/LaunchAgents"

safe_diff "Nix Applications (/Applications)" \
  "$OLD/Applications" "$NEW/Applications"

safe_diff "Nix Fonts (/Library/Fonts)" \
  "$OLD/Library/Fonts" "$NEW/Library/Fonts"

###############################################################################
# Activation commands
###############################################################################
ACTIVATE="$NEW/activate"

echo
echo "== Planned defaults writes (formatted) =="
grep "defaults write" "$ACTIVATE" | while IFS= read -r line; do
  printf ">>> %s\n" "$line"
done || echo "No defaults commands."

echo
echo "== Preference keys that will be changed =="
grep "defaults write" "$ACTIVATE" \
  | sed -E "s/.*defaults write[[:space:]]+([^[:space:]]+)[[:space:]]+'?([^[:space:]]+)'?.*/• Domain: \1   Key: \2/" \
  || echo "No defaults keys."

echo
echo "== pmset / power management changes =="
grep -E "\bpmset\b" "$ACTIVATE" || echo "No pmset changes."

echo
echo "== Firewall changes =="
grep -E "socketfilterfw|ApplicationFirewall" "$ACTIVATE" || echo "No firewall changes."

echo
echo "== nvram changes =="
grep -E "\bnvram\b" "$ACTIVATE" || echo "No nvram changes."

echo
echo "== Homebrew activation (if enabled) =="
grep -E "brew (bundle|install|upgrade|cleanup)" "$ACTIVATE" || echo "No brew bundle lines."

echo
echo "== Summary =="
echo "• Built new system configuration."
echo "• No changes applied yet (this was just a preview)."
echo "• Use this output to understand what defaults, power, firewall, nvram,"
echo "  and Homebrew changes would occur during:"
echo
echo "      sudo darwin-rebuild switch $*"
echo
echo "• When satisfied, run the switch command to activate the new system."
