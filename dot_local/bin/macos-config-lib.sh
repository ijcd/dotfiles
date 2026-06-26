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
    # Exact match; or id is bare domain that matches the domain part of a domain:key target
    if [ "$id" = "$target" ] || [ "$id" = "${target%%:*}" ]; then
      return 0
    fi
    # Bare-domain target: excluded if any key-level exclude covers the same domain
    # (capturing the whole domain would sweep in an excluded key)
    case "$target" in
      *:*) ;;  # domain:key target — already handled by the id==${target%%:*} check above
      *)
        case "$id" in
          "$target":*) return 0 ;;
        esac
        ;;
    esac
  done < <(mc_manifest_rows)
  return 1
}

# Export a defaults domain to repo as XML plist. Refuses excluded domains.
mc_capture_defaults() {
  local domain="$1" dir out tmp
  if mc_is_excluded "$domain"; then
    mc_warn "skip $domain (excluded — owned by settings.nix)"; return 1
  fi
  dir="$(mc_defaults_dir)"; mkdir -p "$dir"
  out="$dir/$domain.plist"
  tmp="$(mktemp)"
  if ! defaults export "$domain" "$tmp" 2>/dev/null; then
    mc_warn "skip $domain (no such domain)"; rm -f "$tmp"; return 1
  fi
  if ! plutil -convert xml1 -o "$out" "$tmp"; then
    mc_warn "failed to convert plist for $domain"; rm -f "$tmp"; return 1
  fi
  rm -f "$tmp"
  printf 'captured %s\n' "$domain"
}

# Import stored plist into the live domain. Pass --dry-run to only print.
mc_apply_defaults() {
  local domain="$1" dry=0 src restart
  shift || true
  [ "${1:-}" = "--dry-run" ] && dry=1
  src="$(mc_defaults_dir)/$domain.plist"
  [ -f "$src" ] || { mc_warn "no captured plist for $domain"; return 1; }
  if ! plutil -lint "$src" >/dev/null 2>&1; then
    mc_warn "invalid plist for $domain"; return 1
  fi
  if [ "$dry" -eq 1 ]; then printf 'would import %s\n' "$domain"; return 0; fi
  defaults import "$domain" "$src"
  # find restart hook for this domain in the manifest
  restart="$(mc_manifest_rows | awk -F"$(printf '\t')" -v d="$domain" '$1=="defaults"&&$2==d{print $3}')"
  restart="$(mc_opt "$restart" restart)"
  killall cfprefsd >/dev/null 2>&1 || true
  [ -n "$restart" ] && { killall "$restart" >/dev/null 2>&1 || true; }
  printf 'applied %s\n' "$domain"
}

# Filesystem-safe slug: "/" -> "_", " " -> "-".
mc_slug() { printf '%s' "$1" | sed 's#/#_#g; s/ /-/g'; }

# Copy matching files from $HOME/<relpath> into repo files/<slug>/.
mc_capture_file() {
  local rel="$1" opts="$2" glob src dst
  glob="$(mc_opt "$opts" match)"; [ -z "$glob" ] && glob="*"
  src="$HOME/$rel"; dst="$(mc_files_dir)/$(mc_slug "$rel")"
  [ -e "$src" ] || { mc_warn "skip $rel (not present)"; return 1; }
  mkdir -p "$dst"
  if [ -d "$src" ]; then
    ( cd "$src" && find . -maxdepth 1 -name "$glob" -type f -print0 ) \
      | while IFS= read -r -d '' f; do cp -p "$src/${f#./}" "$dst/${f#./}" || mc_warn "failed to copy $f"; done
  else
    cp -p "$src" "$dst/"
  fi
  printf 'captured %s\n' "$rel"
}

# Copy files back from repo to $HOME. Refuses to overwrite existing unless --force.
mc_apply_file() {
  local rel="$1" opts="$2"; shift 2 || true
  local dry=0 force=0 a src dstdir f base
  for a in "$@"; do [ "$a" = "--dry-run" ] && dry=1; [ "$a" = "--force" ] && force=1; done
  src="$(mc_files_dir)/$(mc_slug "$rel")"; dstdir="$HOME/$rel"
  [ -d "$src" ] || { mc_warn "no captured files for $rel"; return 1; }
  for f in "$src"/*; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    if [ "$dry" -eq 1 ]; then printf 'would write %s/%s\n' "$rel" "$base"; continue; fi
    mkdir -p "$dstdir"
    if [ -e "$dstdir/$base" ] && [ "$force" -ne 1 ]; then
      mc_warn "refuse overwrite $rel/$base (use --force)"; continue
    fi
    cp -p "$f" "$dstdir/$base"
  done
}
