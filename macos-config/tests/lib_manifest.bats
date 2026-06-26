#!/usr/bin/env bats

setup() {
  REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export MC_REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$MC_REPO_DIR/macos-config"
  cat > "$MC_REPO_DIR/macos-config/manifest.conf" <<'EOF'
# comment
defaults com.example.App restart=App
file Library/Application Support/Hazel match=*.hazelrules restart=Hazel

exclude com.apple.dock
exclude NSGlobalDomain:EnableTilingByEdgeDrag
EOF
  source "$REPO/dot_local/bin/macos-config-lib.sh"
}

@test "manifest_rows skips comments/blanks and tab-separates fields" {
  run mc_manifest_rows
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$(printf 'defaults\tcom.example.App\trestart=App')" ]
  [ "${lines[1]}" = "$(printf 'file\tLibrary/Application Support/Hazel\tmatch=*.hazelrules restart=Hazel')" ]
  [ "${lines[2]}" = "$(printf 'exclude\tcom.apple.dock\t')" ]
}

@test "mc_opt extracts key=value tokens" {
  [ "$(mc_opt 'match=*.hazelrules restart=Hazel' restart)" = "Hazel" ]
  [ "$(mc_opt 'match=*.hazelrules restart=Hazel' match)" = "*.hazelrules" ]
  [ -z "$(mc_opt 'restart=Hazel' missing)" ]
}

@test "mc_opt returns literal glob when cwd contains matching files" {
  # Create a file matching *.hazelrules so an unguarded $opts expansion would
  # replace the glob with the filename instead of the literal token.
  local glob_dir="$BATS_TEST_TMPDIR/glob_test"
  mkdir -p "$glob_dir"
  touch "$glob_dir/MyRules.hazelrules"
  (
    cd "$glob_dir"
    result="$(mc_opt 'match=*.hazelrules restart=Hazel' match)"
    [ "$result" = "*.hazelrules" ]
  )
}

@test "exclude matches exact domain and domain:key" {
  run mc_is_excluded com.apple.dock;                       [ "$status" -eq 0 ]
  run mc_is_excluded NSGlobalDomain:EnableTilingByEdgeDrag; [ "$status" -eq 0 ]
  run mc_is_excluded NSGlobalDomain:KeyRepeat;             [ "$status" -ne 0 ]
  run mc_is_excluded com.example.App;                      [ "$status" -ne 0 ]
}

@test "bare-domain is excluded when any key-level exclude covers that domain" {
  # NSGlobalDomain:EnableTilingByEdgeDrag is in the manifest (set up in setup())
  # Capturing the whole NSGlobalDomain would sweep in that excluded key — must refuse
  run mc_is_excluded NSGlobalDomain
  [ "$status" -eq 0 ]
  # A bare domain with no exclude rows of any kind is not excluded
  run mc_is_excluded com.example.App
  [ "$status" -ne 0 ]
}
