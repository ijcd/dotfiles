#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# refuse: not a jj workspace dir
bad="$(mktemp -d "${TMPDIR:-/tmp}/notjj.XXXXXX")"
if JJ_CLEANUP_WS_ROOT="$bad" "$SCRIPT" __test_rm_ws_dir "$bad" 2>/dev/null; then fail "must refuse non-.jj dir"; fi
[[ -d "$bad" ]] || fail "dir must survive refusal"

# refuse: outside the allowed root prefix
out="$(mktemp -d "${TMPDIR:-/tmp}/outside.XXXXXX")"; mkdir -p "$out/.jj"
if JJ_CLEANUP_WS_ROOT="/nonexistent/prefix" "$SCRIPT" __test_rm_ws_dir "$out" 2>/dev/null; then fail "must refuse outside prefix"; fi
[[ -d "$out" ]] || fail "outside dir must survive"

# accept: under allowed root AND has .jj
good="$(mktemp -d "${TMPDIR:-/tmp}/wsroot.XXXXXX")"; mkdir -p "$good/ws/.jj"
JJ_CLEANUP_WS_ROOT="$good" "$SCRIPT" __test_rm_ws_dir "$good/ws" || fail "should remove valid ws dir"
[[ ! -d "$good/ws" ]] || fail "valid ws dir removed"

rm -rf "$bad" "$out" "$good"; echo "ok: rm_guard"
