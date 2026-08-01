#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stub_dir
stub_cmd gh 'echo "{\"state\":\"MERGED\",\"mergedAt\":\"2026-07-20T00:00:00Z\"}"'
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 2)"
jj bookmark create ijcd/feat -r "$(cid wip/feat)" 2>/dev/null   # fully mirrored → lost:0

out="$("$SCRIPT" scan 2>&1)"
grep -q '^feat' <<<"$out" || fail "row for feat: $out"
[[ "$out" == *MERGED* ]] || fail "shows MERGED"
[[ "$out" == *lost:0* ]] || fail "shows lost:0"
grep -q '^default' <<<"$out" && fail "default must not appear"

cd / && rm -rf "$repo" "$wsA"; echo "ok: scan"
