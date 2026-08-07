#!/usr/bin/env bash
# test_state — flow_branch_state classifies each branch into the pipeline
# vocabulary: draft → mirrored → live → stuck → merged. PR state is injected
# (JJ_MIRROR_LIVE_PRS / JJFLOW_MERGED_PRS); no network.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"
cd "$repo"
mk_layers   # master ← local/main, @ on a child of local/main
jj config set --repo jj-mirror.prime-prefix 'ijcd/' >/dev/null 2>&1

# draft: wip only, no PR bookmark.
jj new local/main >/dev/null 2>&1; echo d > fd; jj commit -m d >/dev/null 2>&1; jj bookmark set wip/draft -r @- >/dev/null 2>&1
# mirrored/live/merged: wip + a hand-placed ijcd/ bookmark (status doesn't care how it got there).
jj new local/main >/dev/null 2>&1; echo m > fm; jj commit -m m >/dev/null 2>&1; jj bookmark set wip/mir -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo m > fm; jj commit -m pm >/dev/null 2>&1; jj bookmark set ijcd/mir -r @- >/dev/null 2>&1
jj new local/main >/dev/null 2>&1; echo l > fl; jj commit -m l >/dev/null 2>&1; jj bookmark set wip/liv -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo l > fl; jj commit -m pl >/dev/null 2>&1; jj bookmark set ijcd/liv -r @- >/dev/null 2>&1
jj new local/main >/dev/null 2>&1; echo g > fg; jj commit -m g >/dev/null 2>&1; jj bookmark set wip/mgd -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo g > fg; jj commit -m pg >/dev/null 2>&1; jj bookmark set ijcd/mgd -r @- >/dev/null 2>&1
# stuck: PR exists AND wip edits `localonly`, which differs between trunk (absent)
# and base (present) — a base divergence sync can't clear. Even marked live, stuck wins.
jj new local/main >/dev/null 2>&1; echo changed > localonly; jj commit -m s >/dev/null 2>&1; jj bookmark set wip/stk -r @- >/dev/null 2>&1
jj new master     >/dev/null 2>&1; echo s > fs; jj commit -m ps >/dev/null 2>&1; jj bookmark set ijcd/stk -r @- >/dev/null 2>&1

state() { JJ_MIRROR_LIVE_PRS="ijcd/liv ijcd/stk" JJFLOW_MERGED_PRS="ijcd/mgd" "$SCRIPT" _state "$1"; }
assert_eq draft    "$(state wip/draft)" "draft: no PR bookmark"
assert_eq mirrored "$(state wip/mir)"   "mirrored: PR bookmark, not open/merged"
assert_eq live     "$(state wip/liv)"   "live: open PR"
assert_eq merged   "$(state wip/mgd)"   "merged: merged PR"
assert_eq stuck    "$(state wip/stk)"   "stuck: base divergence beats live"

cd / && rm -rf "$repo"
echo "ok: state"
