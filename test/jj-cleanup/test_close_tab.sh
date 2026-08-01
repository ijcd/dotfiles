#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stub_dir
calls="$(mktemp "${TMPDIR:-/tmp}/kittycalls.XXXXXX")"
export KITTY_LISTEN_ON="unix:/tmp/fake"
stub_cmd kitty '
if [[ "$1" == "@" && "$2" == "ls" ]]; then
  echo "[{\"tabs\":[{\"title\":\"cc:feat\",\"id\":7}]}]"; exit 0; fi
if [[ "$1" == "@" && "$2" == "close-tab" ]]; then echo "close-tab $*" >> "'"$calls"'"; exit 0; fi'

"$SCRIPT" __test_close_tab feat /tmp/whatever
grep -q 'close-tab' "$calls" || fail "should have closed the cc:feat tab"

# KITTY_LISTEN_ON unset → no-op, no error
unset KITTY_LISTEN_ON
: > "$calls"
"$SCRIPT" __test_close_tab feat /tmp/whatever || fail "no-op when not in kitty"
[[ ! -s "$calls" ]] || fail "must not call kitty when KITTY_LISTEN_ON unset"

rm -f "$calls"; echo "ok: close_tab"
