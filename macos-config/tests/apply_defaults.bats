#!/usr/bin/env bats

DOMAIN="com.ijcd.mctest"

setup() {
  REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export MC_REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$MC_REPO_DIR/macos-config/defaults"
  printf 'defaults %s\n' "$DOMAIN" > "$MC_REPO_DIR/macos-config/manifest.conf"
  source "$REPO/dot_local/bin/macos-config-lib.sh"
  # stored desired state
  defaults write "$DOMAIN" greeting -string "stored"
  defaults export "$DOMAIN" "$MC_REPO_DIR/macos-config/defaults/$DOMAIN.plist"
  plutil -convert xml1 "$MC_REPO_DIR/macos-config/defaults/$DOMAIN.plist"
}
teardown() { defaults delete "$DOMAIN" 2>/dev/null || true; }

@test "apply restores the stored value over a local change" {
  defaults write "$DOMAIN" greeting -string "local-edit"
  mc_apply_defaults "$DOMAIN"
  [ "$(defaults read "$DOMAIN" greeting)" = "stored" ]
}

@test "apply --dry-run does not change the live value" {
  defaults write "$DOMAIN" greeting -string "local-edit"
  mc_apply_defaults "$DOMAIN" --dry-run
  [ "$(defaults read "$DOMAIN" greeting)" = "local-edit" ]
}

@test "macos-config-apply exits non-zero when a domain has no stored plist, still processes others" {
  local domain2="com.ijcd.mctest.missing"
  # manifest: DOMAIN (valid plist in setup) + domain2 (no plist)
  printf 'defaults %s\ndefaults %s\n' "$DOMAIN" "$domain2" \
    > "$MC_REPO_DIR/macos-config/manifest.conf"
  run "$REPO/dot_local/bin/executable_macos-config-apply"
  [ "$status" -ne 0 ]
  # DOMAIN should still have been applied (stored greeting restored)
  [ "$(defaults read "$DOMAIN" greeting 2>/dev/null)" = "stored" ]
}
