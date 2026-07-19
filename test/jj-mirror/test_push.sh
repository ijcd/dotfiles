#!/usr/bin/env bash
# test_push — without jj-vine, push should error cleanly and NOT invoke jj git push.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
echo a1 > f && jj commit -m "a1" >/dev/null 2>&1; jj bookmark set wip/a1 -r @- >/dev/null 2>&1

# Sandbox PATH so jj vine and jj-vine don't exist — but keep jj plus the
# coreutils (grep/awk/shasum/head) the script itself shells out to. jj-vine
# lives in ~/.cargo/bin / the nix store / ~/.local/bin, never /usr/bin, so the
# standard dirs restore coreutils without reintroducing jj-vine.
tmpbin="$(mktemp -d)"
export PATH="$tmpbin:$(command -v jj | xargs dirname):/usr/bin:/bin"
# Also drop the user's global jj config: a `vine` alias there (jj util exec --
# jj-vine) makes `jj vine --help` succeed even with the binary gone, so push
# would take the alias branch instead of the clean not-found error. Empty
# JJ_CONFIG removes user aliases; mkrepo set identity via --repo so commits
# still author.
export JJ_CONFIG="$tmpbin/empty.toml"; : > "$JJ_CONFIG"

set +e
out="$("$SCRIPT" push 2>&1)"
rc=$?
set -e

[[ $rc -ne 0 ]] || fail "push should exit non-zero without jj-vine"
[[ "$out" == *"jj-vine"* ]] || fail "error should mention jj-vine: $out"

cd / && rm -rf "$repo" "$tmpbin"
echo "ok: push (no vine)"
