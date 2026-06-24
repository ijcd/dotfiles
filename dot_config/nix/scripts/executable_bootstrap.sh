#!/usr/bin/env bash
# Bootstrap nix-darwin on this machine with zero per-machine config.
#
# Resolves the flake target automatically:
#   - darwinConfigurations.<LocalHostName>  if a named host exists (bearcat, blackbird, …)
#   - else the per-arch fallback (.#aarch64-darwin / .#x86_64-darwin)
# So a brand-new machine comes up on a working base without editing the flake.
#
# Run AFTER `chezmoi apply` has materialized this dir (~/.config/nix).
set -euo pipefail

# Flake dir = parent of this script's dir. ~/.config/nix is a plain (non-git)
# dir, so nix sees all files — no "untracked invisible to flake" gotcha.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
flake_dir=$(cd -- "$script_dir/.." && pwd)

# Determinate installs nix here; it's not always on sudo's sanitized PATH.
nix=$(command -v nix || echo /nix/var/nix/profiles/default/bin/nix)

host=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
case "$(uname -m)" in
  arm64) arch=aarch64-darwin ;;
  x86_64) arch=x86_64-darwin ;;
  *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

if "$nix" eval --json "$flake_dir#darwinConfigurations" --apply builtins.attrNames 2>/dev/null \
     | tr -d '[]" ' | tr ',' '\n' | grep -qx "$host"; then
  target=$host
  echo "==> named host '$host' found -> building .#$host"
else
  target=$arch
  echo "==> no named host for '$host' -> falling back to .#$arch"
fi

# First switch installs darwin-rebuild into PATH; until then, run it from the
# flake registry. Absolute flake path avoids '~' expanding to root's home.
exec sudo "$nix" run "nix-darwin/master#darwin-rebuild" -- switch --flake "$flake_dir#$target" -L
