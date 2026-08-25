# test/jj-tug/lib.sh — shared helpers for jj-tug tests.
source "$(dirname "${BASH_SOURCE[0]}")/../_jjflow_testwrap.sh"
SCRIPT="${SCRIPT:-$(flow_make_wrapper "jjflow-tug.sh" tug_main)}"

# Isolate the dev's global jj config (no closest_bookmark alias, no diff-formatter).
_iso="$(mktemp -d "${TMPDIR:-/tmp}/jjtug-cfg.XXXXXX")/config.toml"; : > "$_iso"
export JJ_CONFIG="$_iso"

mkrepo() {
  local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/jj-tug-test.XXXXXX")"
  ( cd "$dir"
    jj git init --quiet
    jj config set --repo user.name  "jj-tug-test" 2>/dev/null
    jj config set --repo user.email "test@example.invalid" 2>/dev/null
  )
  printf '%s\n' "$dir"
}

assert_eq() {
  local expected=$1 actual=$2 label=${3:-value}
  if [[ "$expected" != "$actual" ]]; then
    printf 'ASSERTION FAILED: %s\n  expected: %q\n  actual:   %q\n' "$label" "$expected" "$actual" >&2
    return 1
  fi
}
fail() { printf 'FAIL: %s\n' "$*" >&2; return 1; }

cid()    { jj log --no-graph -r "$1" -T 'commit_id.short()' 2>/dev/null | head -n1; }
exists() { jj log --no-graph -r "$1" -T '""' >/dev/null 2>&1; }
