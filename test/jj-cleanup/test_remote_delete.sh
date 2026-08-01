#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
bare="$(mktemp -d "${TMPDIR:-/tmp}/bare.XXXXXX")/o.git"; git init --bare -q "$bare"
jj git remote add origin "$bare" 2>/dev/null
jj bookmark create ijcd/feat -r 'local/main' 2>/dev/null
# jj 0.43: new bookmark pushes via plain --bookmark (no --allow-new flag).
jj git push --bookmark ijcd/feat >/dev/null 2>&1
git --git-dir="$bare" show-ref --verify -q refs/heads/ijcd/feat || fail "precondition: remote branch exists"

"$SCRIPT" __test_del_remote feat
git --git-dir="$bare" show-ref --verify -q refs/heads/ijcd/feat && fail "remote branch must be deleted"

# tolerate already-gone: second call must not error
"$SCRIPT" __test_del_remote feat || fail "second delete must be tolerant"

cd / && rm -rf "$repo" "$bare"; echo "ok: remote_delete"
