#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 2)"
jj bookmark create ijcd/feat -r "$(cid wip/feat)" 2>/dev/null

out="$(JJ_CLEANUP_WS_ROOT="$(dirname "$wsA")" "$SCRIPT" teardown feat --dry-run 2>&1)"
[[ "$out" == *DRYRUN* ]] || fail "dry-run prints DRYRUN lines"
exists wip/feat || fail "dry-run must NOT delete wip/feat"
[[ -d "$wsA" ]] || fail "dry-run must NOT remove dir"

cd / && rm -rf "$repo" "$wsA"; echo "ok: dry_run"
