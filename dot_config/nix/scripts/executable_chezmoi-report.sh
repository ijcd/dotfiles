#!/usr/bin/env bash
#
# chezmoi-report.sh
#
# Quick overview of what chezmoi manages vs not, and per-path queries.
#
# Usage:
#   chezmoi-report.sh           # summary of managed/unmanaged
#   chezmoi-report.sh PATH ...  # say if each PATH is managed or not

set -euo pipefail

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "chezmoi not found in PATH" >&2
  exit 1
fi

# If arguments are given, treat them as paths to query.
if [[ $# -gt 0 ]]; then
  # Build a map of managed paths (exact strings)
  mapfile -t MANAGED < <(chezmoi managed)

  for p in "$@"; do
    # Normalize to an absolute path
    if [[ "$p" != /* ]]; then
      p="$(cd ~ && realpath -m "$p")"
    fi

    if printf '%s\n' "${MANAGED[@]}" | grep -Fxq -- "$p"; then
      echo "MANAGED  : $p"
    else
      echo "UNMANAGED: $p"
    fi
  done

  exit 0
fi

# No args: show a summary

echo "== chezmoi source dir =="
chezmoi source-path

echo
echo "== Managed files =="
chezmoi managed | sed 's/^/MANAGED  : /'

echo
echo "== Unmanaged files under \$HOME (top-level) =="
chezmoi unmanaged "$HOME" | sed 's/^/UNMANAGED: /'

echo
echo "== Unmanaged files under ~/.config (if any) =="
if [[ -d "$HOME/.config" ]]; then
  chezmoi unmanaged "$HOME/.config" | sed 's/^/UNMANAGED: /'
else
  echo "UNMANAGED: (no ~/.config directory)"
fi
