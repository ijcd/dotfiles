#!/usr/bin/env bash
# Precommit gate: nix build --dry-run against chezmoi source flake.
# Catches: unresolvable derivations, version conflicts, broken inputs,
# missing flake input refs at build-plan time. ~10-20s.
# --dry-run means it computes the build plan but doesn't actually build.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
FLAKE_DIR="$ROOT/dot_config/nix"
source "$ROOT/hooks/lib.sh"
HOST="$(gate_host "$FLAKE_DIR")"

echo "▶ nix build --dry-run ${FLAKE_DIR}#darwinConfigurations.${HOST}.config.system.build.toplevel"

cd "$FLAKE_DIR"
if out=$(nix build --dry-run ".#darwinConfigurations.${HOST}.config.system.build.toplevel" 2>&1); then
    echo "✓ build plan OK"
    echo "$out" | tail -3
    exit 0
fi
echo "✗ build plan FAILED"
echo "$out"
echo
echo "Fix the build-plan error above before committing."
echo "Bypass (only if intentional): git commit --no-verify"
exit 1
