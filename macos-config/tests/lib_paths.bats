#!/usr/bin/env bats

setup() {
  REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export MC_REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$MC_REPO_DIR/macos-config"
  source "$REPO/dot_local/bin/macos-config-lib.sh"
}

@test "config/defaults/files dirs resolve under MC_REPO_DIR" {
  [ "$(mc_repo_dir)" = "$MC_REPO_DIR" ]
  [ "$(mc_config_dir)" = "$MC_REPO_DIR/macos-config" ]
  [ "$(mc_defaults_dir)" = "$MC_REPO_DIR/macos-config/defaults" ]
  [ "$(mc_files_dir)" = "$MC_REPO_DIR/macos-config/files" ]
  [ "$(mc_manifest)" = "$MC_REPO_DIR/macos-config/manifest.conf" ]
}
