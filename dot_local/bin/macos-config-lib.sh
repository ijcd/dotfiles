#!/usr/bin/env bash
# Shared helpers for the macos-config-* tools. Sourced, not executed.
# Bash 3.2-safe (macOS system bash).

mc_repo_dir() {
  if [ -n "${MC_REPO_DIR:-}" ]; then echo "$MC_REPO_DIR"; return; fi
  if command -v chezmoi >/dev/null 2>&1; then
    local p; p="$(chezmoi source-path 2>/dev/null || true)"
    if [ -n "$p" ]; then echo "$p"; return; fi
  fi
  echo "$HOME/.local/share/chezmoi"
}

mc_config_dir()   { echo "$(mc_repo_dir)/macos-config"; }
mc_manifest()     { echo "$(mc_config_dir)/manifest.conf"; }
mc_defaults_dir() { echo "$(mc_config_dir)/defaults"; }
mc_files_dir()    { echo "$(mc_config_dir)/files"; }

mc_warn() { printf 'warning: %s\n' "$*" >&2; }
mc_die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
