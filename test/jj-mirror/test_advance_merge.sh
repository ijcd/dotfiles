#!/usr/bin/env bash
# test_advance_merge — the merge-forward primitive in isolation. Given a source
# commit, a new base tip, and an existing live prime tip, it must produce a
# two-parent merge whose first parent is the new base (jj-vine base derivation),
# whose second parent makes it a descendant of the old tip (fast-forward), and
# whose tree is exactly the freshly-derived content. Working copy @ must not move.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"

printf 'base\n' > f; jj commit -m M0 >/dev/null; jj bookmark set master -r @- >/dev/null
# Existing live prime tip E = A on master (its own diff: +a).
jj new master >/dev/null; printf 'base\na\n' > f; jj commit -m A >/dev/null
E=$(jj log --no-graph -r @- -T 'commit_id.short()'); jj bookmark set pr/a -r "$E" >/dev/null
# master advances to M1 (adds an unrelated file); forward move, no --allow-backwards.
jj new master >/dev/null; printf 'base\n' > f; printf 'x\n' > other
jj commit -m M1 >/dev/null; jj bookmark set master -r @- >/dev/null
M1=$(jj log --no-graph -r master -T 'commit_id.short()')
# Source commit S: same +a content, authored on M1 (wip rebased forward).
jj new master >/dev/null; printf 'base\na\n' > f; jj commit -m S >/dev/null
S=$(jj log --no-graph -r @- -T 'commit_id.short()')

at_before=$(jj log --no-graph -r @ -T 'commit_id.short()')
F=$("$SCRIPT" _advance-merge "$S" "$M1" "$E" pr/a)
[[ -n "$F" ]] || fail "advance_merge printed no commit id"

# Two parents, first == new base M1.
parents=$(jj log --no-graph -r "$F" -T 'parents.map(|p| p.commit_id().short()).join("\n")')
assert_eq "$M1" "$(printf '%s\n' "$parents" | head -n1)" "first parent = new base"
[[ $(printf '%s\n' "$parents" | wc -l | tr -d ' ') -eq 2 ]] || fail "F is not a 2-parent merge"

# Append-only: old tip E is an ancestor of F (push fast-forwards, no force).
jj log --no-graph -r "$E & ancestors($F)" -T '"y"' | grep -q y || fail "E not an ancestor of F"

# Tree: derived content on the new base — f has +a, and M1's 'other' is present.
jj file list -r "$F" | grep -qx other || fail "new base (M1) content missing from F"
assert_eq $'base\na' "$(jj file show -r "$F" f)" "derived content in F"

# Bookmark moved to F.
assert_eq "$F" "$(jj log --no-graph -r pr/a -T 'commit_id.short()')" "pr/a advanced to F"

# Working copy @ did not move.
assert_eq "$at_before" "$(jj log --no-graph -r @ -T 'commit_id.short()')" "@ unchanged"

cd / && rm -rf "$repo"
echo "ok: advance_merge"
