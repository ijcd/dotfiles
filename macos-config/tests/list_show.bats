#!/usr/bin/env bats

DOMAIN="com.ijcd.mctest"

setup() {
  REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export MC_REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$MC_REPO_DIR/macos-config/defaults"
  printf 'defaults %s\ndefaults com.example.uncaptured\n' "$DOMAIN" \
    > "$MC_REPO_DIR/macos-config/manifest.conf"
  source "$REPO/dot_local/bin/macos-config-lib.sh"
  printf '<?xml version="1.0"?>\n<plist version="1.0"><dict><key>greeting</key><string>hi</string></dict></plist>\n' \
    > "$MC_REPO_DIR/macos-config/defaults/$DOMAIN.plist"
  # an orphan: stored but not in manifest
  printf '<?xml version="1.0"?>\n<plist version="1.0"><dict/></plist>\n' \
    > "$MC_REPO_DIR/macos-config/defaults/com.orphan.App.plist"
}

@test "list marks captured, missing, and orphan" {
  run "$REPO/dot_local/bin/executable_macos-config-list"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "$DOMAIN"
  echo "$output" | grep -E "com.example.uncaptured.*(✗|missing)"
  echo "$output" | grep -Ei "orphan.*com.orphan.App"
}

@test "show pretty-prints a captured plist" {
  run "$REPO/dot_local/bin/executable_macos-config-show" "$DOMAIN"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "greeting"
}
