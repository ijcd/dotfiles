#!/usr/bin/env bats

DOMAIN="com.ijcd.mctest"

setup() {
  REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export MC_REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$MC_REPO_DIR/macos-config/defaults"
  mkdir -p "$MC_REPO_DIR/macos-config/files"
  printf 'defaults %s\ndefaults com.example.uncaptured\nexclude com.apple.dock\n' "$DOMAIN" \
    > "$MC_REPO_DIR/macos-config/manifest.conf"
  source "$REPO/dot_local/bin/macos-config-lib.sh"
  printf '<?xml version="1.0"?>\n<plist version="1.0"><dict><key>greeting</key><string>hi</string></dict></plist>\n' \
    > "$MC_REPO_DIR/macos-config/defaults/$DOMAIN.plist"
  # an orphan: stored defaults plist with no manifest entry
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

@test "summary line shows correct counts" {
  # setup: 2 declared, 1 captured, 1 missing, 1 excluded, 1 orphan (defaults)
  run "$REPO/dot_local/bin/executable_macos-config-list"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qF "summary: 2 declared · 1 captured · 1 missing · 1 excluded · 1 orphans"
}

@test "--missing shows missing item, excludes captured" {
  run "$REPO/dot_local/bin/executable_macos-config-list" --missing
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "com.example.uncaptured"
  ! echo "$output" | grep -q "$DOMAIN"
}

@test "--captured shows captured item, excludes missing" {
  run "$REPO/dot_local/bin/executable_macos-config-list" --captured
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "$DOMAIN"
  ! echo "$output" | grep -q "com.example.uncaptured"
}

@test "excluded domain appears in excluded section" {
  run "$REPO/dot_local/bin/executable_macos-config-list"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "excluded"
  echo "$output" | grep -q "com.apple.dock"
}

@test "stray dir under files/ is reported as orphan" {
  mkdir -p "$MC_REPO_DIR/macos-config/files/stray-app"
  run "$REPO/dot_local/bin/executable_macos-config-list"
  [ "$status" -eq 0 ]
  echo "$output" | grep -Ei "orphan file.*stray-app"
}

@test "LAST CAPTURED shows — for uncaptured item" {
  run "$REPO/dot_local/bin/executable_macos-config-list"
  [ "$status" -eq 0 ]
  echo "$output" | grep "com.example.uncaptured" | grep -q "—"
}
