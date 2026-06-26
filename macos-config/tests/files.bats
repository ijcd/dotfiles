#!/usr/bin/env bats

setup() {
  REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export MC_REPO_DIR="$BATS_TEST_TMPDIR/repo"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$MC_REPO_DIR/macos-config" "$HOME/src"
  printf 'file src match=*.rules\n' > "$MC_REPO_DIR/macos-config/manifest.conf"
  source "$REPO/dot_local/bin/macos-config-lib.sh"
  printf 'A' > "$HOME/src/a.rules"; printf 'B' > "$HOME/src/b.txt"
}

@test "slug is filesystem-safe" {
  [ "$(mc_slug 'Library/Application Support/Hazel')" = "Library_Application-Support_Hazel" ]
}

@test "capture copies only matching files into the repo" {
  mc_capture_file "src" "match=*.rules"
  [ -f "$(mc_files_dir)/src/a.rules" ]
  [ ! -f "$(mc_files_dir)/src/b.txt" ]
}

@test "apply --force copies files back, plain apply refuses overwrite" {
  mc_capture_file "src" "match=*.rules"
  rm -f "$HOME/src/a.rules"
  run mc_apply_file "src" "match=*.rules"        # no --force, target missing is OK to create
  [ -f "$HOME/src/a.rules" ]
  printf 'LOCAL' > "$HOME/src/a.rules"
  run mc_apply_file "src" "match=*.rules"        # would overwrite -> refuse
  [ "$(cat "$HOME/src/a.rules")" = "LOCAL" ]
  mc_apply_file "src" "match=*.rules" --force
  [ "$(cat "$HOME/src/a.rules")" = "A" ]
}
