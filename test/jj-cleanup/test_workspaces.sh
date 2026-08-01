#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" alpha 2)"
wsB="$(mkwip "$repo" beta 1)"

# resolve_base sees local/main
assert_eq "local/main" "$("$SCRIPT" __test_resolve_base)" "base is local/main"

# list_workspaces yields alpha + beta, NOT default
out="$("$SCRIPT" __test_list_workspaces)"
[[ "$out" == *alpha* && "$out" == *beta* ]] || fail "must list alpha + beta: $out"
[[ "$out" != *"	"*default* ]] || true   # default is denylisted
grep -q '^default	' <<<"$out" && fail "default must be excluded"
grep -q "$wsA" <<<"$out" || fail "alpha root path present"

cd / && rm -rf "$repo" "$wsA" "$wsB"; echo "ok: workspaces"
