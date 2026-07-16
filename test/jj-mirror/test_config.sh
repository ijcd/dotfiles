#!/usr/bin/env bash
# test_config — jj-mirror reads source/prime prefixes from jj config, defaults
# when unset, and rejects overlapping prefixes.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# Defaults
repo="$(mkrepo)"
cd "$repo"
out="$("$SCRIPT" _dump-config 2>&1)"
[[ "$out" == *"source-prefix=wip/"* ]] || fail "default source-prefix not wip/: $out"
[[ "$out" == *"prime-prefix=pr/"*  ]] || fail "default prime-prefix not pr/: $out"

# Custom config
jj config set --repo jj-mirror.source-prefix "src/"
jj config set --repo jj-mirror.prime-prefix  "clean/"
out="$("$SCRIPT" _dump-config 2>&1)"
[[ "$out" == *"source-prefix=src/"*   ]] || fail "custom source-prefix not picked up: $out"
[[ "$out" == *"prime-prefix=clean/"*  ]] || fail "custom prime-prefix not picked up: $out"

# Overlap rejection
jj config set --repo jj-mirror.source-prefix "wip/"
jj config set --repo jj-mirror.prime-prefix  "wip/thing/"
if "$SCRIPT" _dump-config >/dev/null 2>&1; then
  fail "expected non-zero exit on overlapping prefixes"
fi

cd / && rm -rf "$repo"
echo "ok: config"
