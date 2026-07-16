#!/usr/bin/env bash
# test_bootstrap — jj-mirror exists, is executable, prints usage on --help.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

[[ -x "$SCRIPT" ]] || fail "SCRIPT not executable: $SCRIPT"

out="$("$SCRIPT" --help 2>&1)"
[[ "$out" == *"jj-mirror"* ]] || fail "--help output should mention jj-mirror; got: $out"
[[ "$out" == *"sync"* ]] || fail "--help output should list 'sync' command"

echo "ok: bootstrap"
