#!/usr/bin/env bash
# test_push — without jj-vine, push should error cleanly and NOT invoke jj git push.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
echo a1 > f && jj commit -m "a1" >/dev/null 2>&1; jj bookmark set wip/a1 -r @- >/dev/null 2>&1

# Sandbox PATH so jj vine and jj-vine don't exist.
tmpbin="$(mktemp -d)"
export PATH="$tmpbin:$(command -v jj | xargs dirname)"

set +e
out="$("$SCRIPT" push 2>&1)"
rc=$?
set -e

[[ $rc -ne 0 ]] || fail "push should exit non-zero without jj-vine"
[[ "$out" == *"jj-vine"* ]] || fail "error should mention jj-vine: $out"

cd / && rm -rf "$repo" "$tmpbin"
echo "ok: push (no vine)"
