#!/usr/bin/env bats

DOMAIN="com.ijcd.mctest"

setup() {
  REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export MC_REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$MC_REPO_DIR/macos-config/defaults"
  printf 'defaults %s\n' "$DOMAIN" > "$MC_REPO_DIR/macos-config/manifest.conf"
  source "$REPO/dot_local/bin/macos-config-lib.sh"
  defaults write "$DOMAIN" greeting -string "stored"
  defaults export "$DOMAIN" "$MC_REPO_DIR/macos-config/defaults/$DOMAIN.plist"
  plutil -convert xml1 "$MC_REPO_DIR/macos-config/defaults/$DOMAIN.plist"
}
teardown() { defaults delete "$DOMAIN" 2>/dev/null || true; }

@test "diff exits 0 when live matches stored" {
  run "$REPO/dot_local/bin/executable_macos-config-diff"
  [ "$status" -eq 0 ]
}

@test "diff exits 1 and shows change when live differs" {
  defaults write "$DOMAIN" greeting -string "changed"
  run "$REPO/dot_local/bin/executable_macos-config-diff"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "changed"
}
