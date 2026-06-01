#!/usr/bin/env bash
# Fast eval check for the darwin flake. No sudo, no build, no rebuild.
# Catches evaluation-time errors (overlay bugs, module bugs, missing inputs)
# in seconds instead of waiting for darwin-rebuild.
#
# Usage: nix-eval-check [host]   (default host: bearcat)

set -euo pipefail

host="${1:-bearcat}"
flake_dir="${HOME}/.config/nix"

cd "$flake_dir"

echo "→ Evaluating .#darwinConfigurations.${host}.config.system.build.toplevel"
if drv=$(nix eval --raw ".#darwinConfigurations.${host}.config.system.build.toplevel.drvPath" 2>&1); then
  echo "✓ OK"
  echo "  drv: ${drv}"
  exit 0
else
  echo "✗ FAILED"
  echo "$drv"
  exit 1
fi
