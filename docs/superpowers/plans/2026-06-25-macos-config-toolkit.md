# macOS Config Capture/Apply/Merge Toolkit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a small set of shell tools to capture macOS app/system config into the repo (reviewed), apply it back deliberately, and inventory/view it — covering plist-backed config (mergeable) and opaque app blobs (copy-only).

**Architecture:** One sourced shell library (`macos-config-lib.sh`) holds all logic as testable functions; five thin command entrypoints (`capture`, `apply`, `diff`, `list`, `show`) wrap it. A line-based manifest drives everything. Captured data is repo-only under `macos-config/` (chezmoi-ignored). Plist tier round-trips via `defaults export` → `plutil -convert xml1` (git-diffable); file tier is a byte copy.

**Tech Stack:** Bash (3.2-compatible — macOS system bash), macOS `defaults` + `plutil`, `git`, `cp`. Tests: `bats` run via `nix run nixpkgs#bats` (no install needed).

## Global Constraints

- **Dependencies:** only `defaults`, `plutil`, `git`, `cp`, `diff` — all macOS-native. No new runtime deps.
- **Bash 3.2-safe:** no associative arrays, no `${var^^}`, no `mapfile`. Indexed arrays and process substitution are fine.
- **Scripts:** live in `dot_local/bin/` with chezmoi `executable_` prefix → deployed to `~/.local/bin`. The sourced library has no prefix (deployed mode 0644).
- **Storage:** `macos-config/` at repo root, **repo-only** (added to `.chezmoiignore`). It is *source*, never deployed to `~`.
- **Disjoint ownership:** `capture` MUST refuse any domain or `domain:key` listed as `exclude` in the manifest (these are owned by `settings.nix`).
- **Tiers:** Tier 1 = `defaults` domains, stored as XML plist (`plutil -convert xml1`). Tier 2 = files, stored as byte copies (binary, not diff-mergeable).
- **Apply is explicit:** never auto-run from `chezmoi apply`/`darwin-rebuild`. Tier-2 apply (overwrites files) requires `--force`.
- **Repo resolution:** library resolves the repo via `$MC_REPO_DIR` if set (tests use this), else `chezmoi source-path`, else `~/.local/share/chezmoi`.

---

## File Structure

- `dot_local/bin/macos-config-lib.sh` — all logic as `mc_*` functions (sourced).
- `dot_local/bin/executable_macos-config-capture` — thin entrypoint.
- `dot_local/bin/executable_macos-config-apply` — thin entrypoint.
- `dot_local/bin/executable_macos-config-diff` — thin entrypoint.
- `dot_local/bin/executable_macos-config-list` — thin entrypoint.
- `dot_local/bin/executable_macos-config-show` — thin entrypoint.
- `macos-config/manifest.conf` — the manifest (repo-only).
- `macos-config/defaults/` — captured Tier-1 XML plists (repo-only).
- `macos-config/files/` — captured Tier-2 blobs (repo-only).
- `macos-config/tests/*.bats` — bats tests (repo-only).
- `.chezmoiignore` — add `macos-config` so the tree is never deployed.

Library functions (the interface every task builds on):

```
mc_repo_dir            -> path to chezmoi source repo
mc_config_dir          -> $repo/macos-config
mc_manifest            -> $config_dir/manifest.conf
mc_defaults_dir        -> $config_dir/defaults
mc_files_dir           -> $config_dir/files
mc_manifest_rows       -> emits "<tier>\t<id>\t<opts>" per non-comment line
mc_opt <opts> <key>    -> value of key=val token in an opts string ("" if absent)
mc_is_excluded <dom[:key]> -> exit 0 if excluded by manifest
mc_capture_defaults <domain>        -> export domain to $defaults_dir/<domain>.plist (xml)
mc_apply_defaults <domain> [--dry-run] -> import $defaults_dir/<domain>.plist into domain
mc_slug <path>         -> filesystem-safe slug for a $HOME-relative path
mc_capture_file <relpath> <opts>    -> copy file(s) into $files_dir/<slug>/
mc_apply_file <relpath> <opts> [--force] -> copy file(s) back under $HOME
```

---

## Task 1: Scaffolding + repo/path resolution

**Files:**
- Create: `dot_local/bin/macos-config-lib.sh`
- Create: `macos-config/manifest.conf`
- Modify: `.chezmoiignore` (add `macos-config`)
- Test: `macos-config/tests/lib_paths.bats`

**Interfaces:**
- Produces: `mc_repo_dir`, `mc_config_dir`, `mc_manifest`, `mc_defaults_dir`, `mc_files_dir`.

- [ ] **Step 1: Write the failing test**

`macos-config/tests/lib_paths.bats`:
```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix run nixpkgs#bats -- macos-config/tests/lib_paths.bats`
Expected: FAIL — `macos-config-lib.sh` does not exist (source error).

- [ ] **Step 3: Write minimal implementation**

`dot_local/bin/macos-config-lib.sh`:
```bash
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
```

Create `macos-config/manifest.conf`:
```
# macos-config manifest. One entry per line:
#   defaults <domain> [restart=<proc>]            Tier 1 (plist, mergeable)
#   file     <path-under-$HOME> [restart=<proc>] [match=<glob>]   Tier 2 (blob)
#   exclude  <domain[:key]>                        owned by settings.nix; never captured
# Lines starting with # and blank lines are ignored.
```

Add to `.chezmoiignore` (under the repo-only section near `archive`/`plans`):
```
macos-config                      # repo-only: capture/apply source, not deployed
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix run nixpkgs#bats -- macos-config/tests/lib_paths.bats`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/macos-config-lib.sh macos-config/manifest.conf .chezmoiignore macos-config/tests/lib_paths.bats
git commit -m "macos-config: scaffolding + path resolution lib"
```

---

## Task 2: Manifest parser + exclude matcher

**Files:**
- Modify: `dot_local/bin/macos-config-lib.sh`
- Test: `macos-config/tests/lib_manifest.bats`

**Interfaces:**
- Consumes: `mc_manifest`, `mc_warn`.
- Produces: `mc_manifest_rows` (emits `<tier>\t<id>\t<opts>`), `mc_opt <opts> <key>`, `mc_is_excluded <dom[:key]>`.

- [ ] **Step 1: Write the failing test**

`macos-config/tests/lib_manifest.bats`:
```bash
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

@test "exclude matches exact domain and domain:key" {
  run mc_is_excluded com.apple.dock;                       [ "$status" -eq 0 ]
  run mc_is_excluded NSGlobalDomain:EnableTilingByEdgeDrag; [ "$status" -eq 0 ]
  run mc_is_excluded NSGlobalDomain:KeyRepeat;             [ "$status" -ne 0 ]
  run mc_is_excluded com.example.App;                      [ "$status" -ne 0 ]
}
```

Note: the second field (`id`) may contain spaces (e.g. an Application Support path), so the parser must treat field 1 = first token, field 2 = everything up to a 2-space gap or known option start. To keep it simple and unambiguous, **the manifest uses the first token as tier, the second token as id, and the remainder as opts** — and `file` paths with spaces are written with the path as a single token using `\ ` is avoided by requiring quotes. Simpler rule adopted here: id is a single whitespace-delimited token; file paths containing spaces are written with `+` placeholders is rejected. Instead, the parser takes tier=field1, id=field2, opts=field3.., and file paths with spaces are supported by quoting in the manifest with double quotes.

To avoid quote-parsing in bash 3.2, adopt this concrete rule used by the test above: **fields are split on runs of whitespace; for `file` the path may contain single spaces and is reconstructed as everything between field 2 and the first `key=` token.** Implement accordingly.

- [ ] **Step 2: Run test to verify it fails**

Run: `nix run nixpkgs#bats -- macos-config/tests/lib_manifest.bats`
Expected: FAIL — `mc_manifest_rows: command not found`.

- [ ] **Step 3: Write minimal implementation**

Append to `dot_local/bin/macos-config-lib.sh`:
```bash
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
  for tok in $opts; do
    case "$tok" in
      "$key"=*) printf '%s' "${tok#*=}"; return 0 ;;
    esac
  done
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix run nixpkgs#bats -- macos-config/tests/lib_manifest.bats`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/macos-config-lib.sh macos-config/tests/lib_manifest.bats
git commit -m "macos-config: manifest parser + exclude matcher"
```

---

## Task 3: Capture (Tier 1 defaults) + entrypoint

**Files:**
- Modify: `dot_local/bin/macos-config-lib.sh`
- Create: `dot_local/bin/executable_macos-config-capture`
- Test: `macos-config/tests/capture_defaults.bats`

**Interfaces:**
- Consumes: `mc_defaults_dir`, `mc_is_excluded`, `mc_manifest_rows`, `mc_opt`, `mc_warn`.
- Produces: `mc_capture_defaults <domain>` → writes `$defaults_dir/<domain>.plist` (XML); refuses excluded domains. Entrypoint `macos-config-capture [item...]`.

- [ ] **Step 1: Write the failing test**

`macos-config/tests/capture_defaults.bats`:
```bash
#!/usr/bin/env bats

DOMAIN="com.ijcd.mctest"

setup() {
  REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export MC_REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$MC_REPO_DIR/macos-config"
  printf 'defaults %s\nexclude com.apple.dock\n' "$DOMAIN" \
    > "$MC_REPO_DIR/macos-config/manifest.conf"
  source "$REPO/dot_local/bin/macos-config-lib.sh"
  defaults write "$DOMAIN" greeting -string "hello"
}
teardown() { defaults delete "$DOMAIN" 2>/dev/null || true; }

@test "capture_defaults writes an XML plist containing the key" {
  mc_capture_defaults "$DOMAIN"
  local out="$MC_REPO_DIR/macos-config/defaults/$DOMAIN.plist"
  [ -f "$out" ]
  head -1 "$out" | grep -q '<?xml'
  grep -q 'greeting' "$out"
  grep -q 'hello' "$out"
}

@test "capture_defaults refuses an excluded domain" {
  run mc_capture_defaults com.apple.dock
  [ "$status" -ne 0 ]
  [ ! -f "$MC_REPO_DIR/macos-config/defaults/com.apple.dock.plist" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix run nixpkgs#bats -- macos-config/tests/capture_defaults.bats`
Expected: FAIL — `mc_capture_defaults: command not found`.

- [ ] **Step 3: Write minimal implementation**

Append to `dot_local/bin/macos-config-lib.sh`:
```bash
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
  plutil -convert xml1 -o "$out" "$tmp"
  rm -f "$tmp"
  printf 'captured %s\n' "$domain"
}
```

Create `dot_local/bin/executable_macos-config-capture`:
```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/macos-config-lib.sh"

# Usage: macos-config-capture [item...]   (no items = all manifest entries)
want() { [ "$#" -eq 1 ] && return 0; shift; for w in "$@"; do [ "$w" = "$1" ] && return 0; done; return 1; }

args=("$@")
mc_manifest_rows | while IFS="$(printf '\t')" read -r tier id opts; do
  if [ "${#args[@]}" -gt 0 ]; then
    skip=1; for a in "${args[@]}"; do [ "$a" = "$id" ] && skip=0; done
    [ "$skip" -eq 1 ] && continue
  fi
  case "$tier" in
    defaults) mc_capture_defaults "$id" || true ;;
    file)     : ;;  # implemented in Task 7
    exclude)  : ;;
  esac
done
echo "Review with: git -C \"$(mc_repo_dir)\" diff -- macos-config/"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix run nixpkgs#bats -- macos-config/tests/capture_defaults.bats`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/macos-config-lib.sh dot_local/bin/executable_macos-config-capture macos-config/tests/capture_defaults.bats
git commit -m "macos-config: capture Tier-1 defaults + entrypoint"
```

---

## Task 4: Apply (Tier 1 defaults) + --dry-run + entrypoint

**Files:**
- Modify: `dot_local/bin/macos-config-lib.sh`
- Create: `dot_local/bin/executable_macos-config-apply`
- Test: `macos-config/tests/apply_defaults.bats`

**Interfaces:**
- Consumes: `mc_defaults_dir`, `mc_manifest_rows`, `mc_opt`.
- Produces: `mc_apply_defaults <domain> [--dry-run]` → imports stored plist into the live domain, flushes cfprefsd, runs `restart=` hook. Entrypoint `macos-config-apply [--dry-run] [item...]`.

- [ ] **Step 1: Write the failing test**

`macos-config/tests/apply_defaults.bats`:
```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix run nixpkgs#bats -- macos-config/tests/apply_defaults.bats`
Expected: FAIL — `mc_apply_defaults: command not found`.

- [ ] **Step 3: Write minimal implementation**

Append to `dot_local/bin/macos-config-lib.sh`:
```bash
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
```

Create `dot_local/bin/executable_macos-config-apply`:
```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/macos-config-lib.sh"

# Usage: macos-config-apply [--dry-run] [--force] [item...]
dry=""; force=""; items=()
for a in "$@"; do
  case "$a" in
    --dry-run) dry="--dry-run" ;;
    --force)   force="--force" ;;
    *)         items+=("$a") ;;
  esac
done

mc_manifest_rows | while IFS="$(printf '\t')" read -r tier id opts; do
  if [ "${#items[@]}" -gt 0 ]; then
    skip=1; for a in "${items[@]}"; do [ "$a" = "$id" ] && skip=0; done
    [ "$skip" -eq 1 ] && continue
  fi
  case "$tier" in
    defaults) mc_apply_defaults "$id" $dry || true ;;
    file)     mc_apply_file "$id" "$opts" $dry $force || true ;;  # Task 7
    exclude)  : ;;
  esac
done
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix run nixpkgs#bats -- macos-config/tests/apply_defaults.bats`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/macos-config-lib.sh dot_local/bin/executable_macos-config-apply macos-config/tests/apply_defaults.bats
git commit -m "macos-config: apply Tier-1 defaults (+dry-run) + entrypoint"
```

---

## Task 5: Diff

**Files:**
- Create: `dot_local/bin/executable_macos-config-diff`
- Test: `macos-config/tests/diff.bats`

**Interfaces:**
- Consumes: `mc_defaults_dir`, `mc_manifest_rows`.
- Produces: entrypoint `macos-config-diff [item...]` → prints unified diff of live-vs-stored per Tier-1 domain; exit 1 if any differ, 0 if all match.

- [ ] **Step 1: Write the failing test**

`macos-config/tests/diff.bats`:
```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix run nixpkgs#bats -- macos-config/tests/diff.bats`
Expected: FAIL — file not found / non-executable.

- [ ] **Step 3: Write minimal implementation**

`dot_local/bin/executable_macos-config-diff`:
```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(cd "$(dirname "$0")" && pwd)/macos-config-lib.sh"

# Usage: macos-config-diff [item...]   exit 1 if anything differs
items=("$@")
rc=0
while IFS="$(printf '\t')" read -r tier id opts; do
  [ "$tier" = "defaults" ] || continue
  if [ "${#items[@]}" -gt 0 ]; then
    skip=1; for a in "${items[@]}"; do [ "$a" = "$id" ] && skip=0; done
    [ "$skip" -eq 1 ] && continue
  fi
  stored="$(mc_defaults_dir)/$id.plist"
  [ -f "$stored" ] || { echo "## $id: not captured"; rc=1; continue; }
  live="$(mktemp)"
  if defaults export "$id" - 2>/dev/null | plutil -convert xml1 -o "$live" - 2>/dev/null; then
    if ! diff -u "$stored" "$live" >/tmp/mcdiff.$$ 2>/dev/null; then
      echo "## $id"; sed "s#$live#(live)#" /tmp/mcdiff.$$; rc=1
    fi
    rm -f /tmp/mcdiff.$$
  fi
  rm -f "$live"
done < <(mc_manifest_rows)
exit $rc
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix run nixpkgs#bats -- macos-config/tests/diff.bats`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/executable_macos-config-diff macos-config/tests/diff.bats
git commit -m "macos-config: diff (live vs stored)"
```

---

## Task 6: List + Show

**Files:**
- Create: `dot_local/bin/executable_macos-config-list`
- Create: `dot_local/bin/executable_macos-config-show`
- Test: `macos-config/tests/list_show.bats`

**Interfaces:**
- Consumes: `mc_manifest_rows`, `mc_defaults_dir`, `mc_files_dir`, `mc_config_dir`.
- Produces: entrypoints `macos-config-list` (inventory table + orphan detection) and `macos-config-show <item>` (readable view).

- [ ] **Step 1: Write the failing test**

`macos-config/tests/list_show.bats`:
```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix run nixpkgs#bats -- macos-config/tests/list_show.bats`
Expected: FAIL — entrypoints missing.

- [ ] **Step 3: Write minimal implementation**

`dot_local/bin/executable_macos-config-list`:
```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(cd "$(dirname "$0")" && pwd)/macos-config-lib.sh"

ddir="$(mc_defaults_dir)"
printf '%-40s %-8s %-9s %s\n' "ITEM" "TIER" "CAPTURED" "RESTART"
seen=""
while IFS="$(printf '\t')" read -r tier id opts; do
  [ "$tier" = "exclude" ] && continue
  case "$tier" in
    defaults) [ -f "$ddir/$id.plist" ] && cap="✓" || cap="✗ missing" ;;
    file)     [ -d "$(mc_files_dir)/$(mc_slug "$id")" ] && cap="✓" || cap="✗ missing" ;;
    *)        cap="?" ;;
  esac
  printf '%-40s %-8s %-9s %s\n' "$id" "$tier" "$cap" "$(mc_opt "$opts" restart)"
  seen="$seen $id"
done < <(mc_manifest_rows)

# orphans: stored defaults plists with no manifest entry
if [ -d "$ddir" ]; then
  for f in "$ddir"/*.plist; do
    [ -e "$f" ] || continue
    dom="$(basename "$f" .plist)"
    case " $seen " in *" $dom "*) : ;; *) echo "orphan (no manifest entry): $dom" ;; esac
  done
fi
```

`dot_local/bin/executable_macos-config-show`:
```bash
#!/usr/bin/env bash
set -uo pipefail
source "$(cd "$(dirname "$0")" && pwd)/macos-config-lib.sh"

[ "$#" -eq 1 ] || mc_die "usage: macos-config-show <item>"
item="$1"
row="$(mc_manifest_rows | awk -F"$(printf '\t')" -v i="$item" '$2==i{print; exit}')"
tier="$(printf '%s' "$row" | cut -f1)"
case "$tier" in
  file)
    dir="$(mc_files_dir)/$(mc_slug "$item")"
    echo "# $item (Tier 2 — binary blob, not renderable)"
    [ -d "$dir" ] && ls -lhR "$dir" || echo "(not captured)"
    ;;
  *)
    f="$(mc_defaults_dir)/$item.plist"
    [ -f "$f" ] || mc_die "not captured: $item"
    n="$(plutil -convert xml1 -o - "$f" | grep -c '<key>')"
    echo "# $item ($n keys)"
    plutil -p "$f"
    ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix run nixpkgs#bats -- macos-config/tests/list_show.bats`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/executable_macos-config-list dot_local/bin/executable_macos-config-show macos-config/tests/list_show.bats
git commit -m "macos-config: list (inventory/orphans) + show"
```

---

## Task 7: Tier 2 files (capture/apply blobs) + slug

**Files:**
- Modify: `dot_local/bin/macos-config-lib.sh`
- Test: `macos-config/tests/files.bats`

**Interfaces:**
- Consumes: `mc_files_dir`, `mc_opt`.
- Produces: `mc_slug <relpath>`, `mc_capture_file <relpath> <opts>`, `mc_apply_file <relpath> <opts> [--dry-run] [--force]`.

- [ ] **Step 1: Write the failing test**

`macos-config/tests/files.bats`:
```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix run nixpkgs#bats -- macos-config/tests/files.bats`
Expected: FAIL — `mc_slug: command not found`.

- [ ] **Step 3: Write minimal implementation**

Append to `dot_local/bin/macos-config-lib.sh`:
```bash
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
      | while IFS= read -r -d '' f; do cp -p "$src/${f#./}" "$dst/${f#./}"; done
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
  mkdir -p "$dstdir"
  for f in "$src"/*; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    if [ "$dry" -eq 1 ]; then printf 'would write %s/%s\n' "$rel" "$base"; continue; fi
    if [ -e "$dstdir/$base" ] && [ "$force" -ne 1 ]; then
      mc_warn "refuse overwrite $rel/$base (use --force)"; continue
    fi
    cp -p "$f" "$dstdir/$base"
  done
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix run nixpkgs#bats -- macos-config/tests/files.bats`
Expected: PASS (3 tests).

- [ ] **Step 5: Wire file capture into the capture entrypoint**

In `dot_local/bin/executable_macos-config-capture`, replace the `file) : ;;` line with:
```bash
    file)     mc_capture_file "$id" "$opts" || true ;;
```

- [ ] **Step 6: Run all tests + shellcheck**

Run: `nix run nixpkgs#bats -- macos-config/tests/`
Expected: PASS (all).
Run: `nix run nixpkgs#shellcheck -- dot_local/bin/macos-config-lib.sh dot_local/bin/executable_macos-config-*`
Expected: no errors (warnings acceptable; fix any error-level).

- [ ] **Step 7: Commit**

```bash
git add dot_local/bin/macos-config-lib.sh dot_local/bin/executable_macos-config-capture macos-config/tests/files.bats
git commit -m "macos-config: Tier-2 file capture/apply + slug"
```

---

## Task 8: Seed the manifest + exclude entries; document

**Files:**
- Modify: `macos-config/manifest.conf`
- Modify: `CLAUDE.md` (one line under the nix section about the exclude discipline)
- Test: manual (`macos-config-list`)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Populate the manifest**

Replace the body of `macos-config/manifest.conf` (keep the header comment) with real entries:
```
defaults com.knollsoft.Rectangle restart=Rectangle
defaults com.runningwithcrayons.Alfred-Preferences

file Library/Application Support/Hazel match=*.hazelrules restart=Hazel

# Owned by settings.nix — never capture these:
exclude com.apple.dock
exclude com.apple.finder
exclude com.apple.Terminal
exclude NSGlobalDomain:EnableTilingByEdgeDrag
exclude NSGlobalDomain:EnableTopTilingByEdgeDrag
exclude com.apple.screencapture
```

- [ ] **Step 2: Document the one discipline**

Add to `CLAUDE.md` under the nix "Where to add things" area:
```
- macOS app/system config you tune live and capture back → `macos-config/` toolkit (`macos-config-capture/apply/list/show/diff`). When you add a declarative key to `settings.nix`, add a matching `exclude` line to `macos-config/manifest.conf` so the toolkit never captures nix-owned keys.
```

- [ ] **Step 3: Smoke test on the real machine**

Run: `chezmoi apply ~/.local/bin` (deploy the scripts), then:
```bash
macos-config-list
macos-config-capture com.knollsoft.Rectangle
git -C "$(chezmoi source-path)" diff -- macos-config/
```
Expected: `list` shows the manifest with Rectangle ✗→ then ✓ after capture; `diff` shows the new plist.

- [ ] **Step 4: Commit**

```bash
git add macos-config/manifest.conf CLAUDE.md macos-config/defaults/
git commit -m "macos-config: seed manifest (Rectangle/Alfred/Hazel) + exclude nix-owned + docs"
```

---

## Self-Review

**Spec coverage:**
- Capture/apply/diff/list/show — Tasks 3,4,5,6. ✓
- Tier 1 (plist, mergeable) — Tasks 3,4. ✓ Tier 2 (blob copy, --force) — Task 7. ✓
- Bidirectional + review-on-capture — capture writes to working tree, prints `git diff` hint (Task 3); never auto-commits. ✓
- Explicit apply, never auto — standalone entrypoints, not wired to chezmoi/darwin-rebuild. ✓
- Disjoint ownership / exclude guard — Task 2 (matcher), Task 3 (capture refuses), Task 8 (seed excludes). ✓
- Orphan detection — Task 6. ✓
- Storage repo-only — Task 1 (`.chezmoiignore`). ✓
- Deps macOS-native + bash 3.2 — Global Constraints; code avoids bashisms beyond 3.2. ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code. The only forward-reference (`mc_apply_file` used in Task 4's apply entrypoint) is defined in Task 7; Task 4's tests only exercise `defaults`, so it passes independently, and Task 7 completes the `file` path.

**Type/name consistency:** `mc_capture_defaults`, `mc_apply_defaults`, `mc_capture_file`, `mc_apply_file`, `mc_slug`, `mc_opt`, `mc_is_excluded`, `mc_manifest_rows` — names used consistently across tasks. Storage paths (`defaults/<domain>.plist`, `files/<slug>/`) consistent.

**Note:** Tasks 3 and 4 use a real throwaway domain `com.ijcd.mctest` via `defaults` — safe (created/deleted in setup/teardown), never touches real settings.
