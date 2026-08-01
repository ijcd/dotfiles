#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

out="$("$SCRIPT" help 2>&1)"
[[ "$out" == *scan* && "$out" == *teardown* ]] || fail "help must list scan + teardown"

# unknown subcommand → exit 2
if "$SCRIPT" bogus >/dev/null 2>&1; then fail "unknown subcommand should exit non-zero"; fi
rc=0; "$SCRIPT" bogus >/dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "unknown subcommand exit code"

echo "ok: help"
