#!/usr/bin/env bash
# Precommit gate: nix eval against chezmoi source flake.
# Catches: module composition errors, overlay bugs, syntax errors,
# missing input refs. ~10s.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
FLAKE_DIR="$ROOT/dot_config/nix"
source "$ROOT/hooks/lib.sh"
HOST="$(gate_host "$FLAKE_DIR")"

echo "▶ nix eval ${FLAKE_DIR}#darwinConfigurations.${HOST}.config.system.build.toplevel.drvPath"

cd "$FLAKE_DIR"
if drv=$(nix eval --raw ".#darwinConfigurations.${HOST}.config.system.build.toplevel.drvPath" 2>&1); then
    echo "✓ eval OK"
    echo "  drv: ${drv}"
    exit 0
fi
echo "✗ eval FAILED"
echo "$drv"
echo
echo "Fix the eval error above before committing."
echo "Bypass (only if intentional): git commit --no-verify"
exit 1
