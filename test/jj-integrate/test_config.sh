#!/usr/bin/env bash
# test_config — the config subcommand reports the resolved bookmark, base, all,
# members, and how to change them.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
mkbase; mkwip wip/a
"$SCRIPT" add wip/a >/dev/null 2>&1

out="$("$SCRIPT" config 2>&1)"
[[ "$out" == *"local/integration"* ]] || fail "config should show the bookmark: $out"
[[ "$out" == *"local/main"*        ]] || fail "config should show the base: $out"
[[ "$out" == *"wip/a"*             ]] || fail "config should show the member: $out"
[[ "$out" == *"jj config set --repo jj-integrate.bookmark"* ]] || fail "config should show how to set the bookmark: $out"

cd / && rm -rf "$repo"; echo "ok: config"
