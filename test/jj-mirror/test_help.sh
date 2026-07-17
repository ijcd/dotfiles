#!/usr/bin/env bash
# test_help — per-command help is reachable via both `<cmd> --help` and
# `help <cmd>`, and rejects unknown commands with a non-zero exit.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# Global help
out="$("$SCRIPT" --help 2>&1)"
[[ "$out" == *"jj-mirror"* && "$out" == *"Commands:"* && "$out" == *"sync"* ]] \
  || fail "--help must show the top-level overview + command list: $out"

# Per-command --help
for cmd in sync status push abandon; do
  out="$("$SCRIPT" "$cmd" --help 2>&1)"
  [[ "$out" == *"Usage:"* && "$out" == *"$cmd"* ]] \
    || fail "$cmd --help must include Usage line for $cmd: $out"

  out="$("$SCRIPT" "$cmd" -h 2>&1)"
  [[ "$out" == *"Usage:"* ]] \
    || fail "$cmd -h must also work: $out"
done

# `help <cmd>` form
for cmd in sync status push abandon; do
  out="$("$SCRIPT" help "$cmd" 2>&1)"
  [[ "$out" == *"Usage:"* && "$out" == *"$cmd"* ]] \
    || fail "help $cmd must include Usage line for $cmd: $out"
done

# `help <bogus>` → non-zero, error, then fall-through to global usage
set +e
out="$("$SCRIPT" help bogus 2>&1)"
rc=$?
set -e
[[ $rc -ne 0 ]] || fail "help <unknown-cmd> should exit non-zero"
[[ "$out" == *"no help for unknown"* ]] || fail "help <unknown-cmd> should name the unknown: $out"

# Per-command --help must NOT load config or hit jj — no repo required.
tmp="$(mktemp -d)"
cd "$tmp"
out="$("$SCRIPT" sync --help 2>&1)"
[[ "$out" == *"Usage:"* ]] || fail "sync --help must work outside any jj repo: $out"
cd / && rm -rf "$tmp"

echo "ok: help"
