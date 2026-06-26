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

# Emit normalized rows: "<tier>\t<id>\t<opts>". For `file`, id may contain
# spaces: id is everything between the tier token and the first key=val token
# (or end of line); opts is the key=val remainder.
mc_manifest_rows() {
  local mf line tier rest id opts
  mf="$(mc_manifest)"
  [ -f "$mf" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    # trim
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue
    tier="${line%%[[:space:]]*}"
    rest="${line#"$tier"}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    # split rest into id (up to first key=val) and opts (the key=val tail)
    if printf '%s' "$rest" | grep -Eq '[[:space:]][a-z]+='; then
      opts="$(printf '%s' "$rest" | grep -oE '[a-z]+=[^[:space:]]+([[:space:]]+[a-z]+=[^[:space:]]+)*$')"
      id="${rest%"$opts"}"
      id="${id%"${id##*[![:space:]]}"}"
    else
      id="$rest"; opts=""
    fi
    printf '%s\t%s\t%s\n' "$tier" "$id" "$opts"
  done < "$mf"
}

# mc_opt "<opts>" <key> -> value or empty
mc_opt() {
  local opts="$1" key="$2" tok
  set -f
  for tok in $opts; do
    set +f
    case "$tok" in
      "$key"=*) printf '%s' "${tok#*=}"; return 0 ;;
    esac
  done
  set +f
  return 0
}

# mc_is_excluded <domain[:key]> -> 0 if excluded
mc_is_excluded() {
  local target="$1" tier id opts
  while IFS="$(printf '\t')" read -r tier id opts; do
    [ "$tier" = "exclude" ] || continue
    if [ "$id" = "$target" ] || [ "$id" = "${target%%:*}" ]; then
      return 0
    fi
  done < <(mc_manifest_rows)
  return 1
}
