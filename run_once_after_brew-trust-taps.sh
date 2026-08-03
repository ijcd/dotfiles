#!/bin/bash
# Trust third-party Homebrew taps that ship CASKS, so `brew bundle` (run by
# darwin-rebuild activation) doesn't hard-abort at the untrusted-tap gate.
#
# Homebrew refuses to load a cask from an untrusted third-party tap; the refusal
# aborts the WHOLE bundle before installing anything, and nix-darwin treats that
# failure as non-fatal — so the switch "succeeds" while installing nothing new.
# Formula-only taps (raine/workmux, ijcd/tap) are only warned, not refused, so
# they don't need this. See dot_config/nix/README.md.
#
# Idempotent: skips taps already trusted; safe to re-run.

set -euo pipefail
[[ "$(uname)" == "Darwin" ]] || exit 0
command -v brew >/dev/null 2>&1 || { echo "[brew-trust] brew not found; skipping" >&2; exit 0; }

export HOMEBREW_NO_AUTO_UPDATE=1

# Third-party taps whose casks trip Homebrew's untrusted-tap refusal.
TAPS=(
  "nikitabobko/tap"   # aerospace (tiling WM) — cask-only in this tap, not in homebrew/cask
)

for tap in "${TAPS[@]}"; do
  # ensure the tap is present first — trust needs it, and run_once may fire
  # before the rebuild taps it. `brew tap` is a no-op if already tapped.
  brew tap "$tap" >/dev/null 2>&1 || true

  if brew tap-info "$tap" 2>/dev/null | grep -q "Trusted"; then
    continue
  fi

  brew trust "$tap"
  echo "[brew-trust] trusted $tap"
done
