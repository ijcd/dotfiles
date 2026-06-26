#!/usr/bin/env bats

DOMAIN="com.ijcd.mctest"

setup() {
  REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export MC_REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$MC_REPO_DIR/macos-config"
  printf 'defaults %s\nexclude com.apple.dock\n' "$DOMAIN" \
    > "$MC_REPO_DIR/macos-config/manifest.conf"
  source "$REPO/dot_local/bin/macos-config-lib.sh"
  defaults write "$DOMAIN" greeting -string "hello"
}
teardown() { defaults delete "$DOMAIN" 2>/dev/null || true; }

@test "capture_defaults writes an XML plist containing the key" {
  mc_capture_defaults "$DOMAIN"
  local out="$MC_REPO_DIR/macos-config/defaults/$DOMAIN.plist"
  [ -f "$out" ]
  head -1 "$out" | grep -q '<?xml'
  grep -q 'greeting' "$out"
  grep -q 'hello' "$out"
}

@test "capture_defaults refuses an excluded domain" {
  run mc_capture_defaults com.apple.dock
  [ "$status" -ne 0 ]
  [ ! -f "$MC_REPO_DIR/macos-config/defaults/com.apple.dock.plist" ]
}
