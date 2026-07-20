# test/jj-integrate/lib.sh — shared helpers for jj-integrate tests.
# Sourced by every test_*.sh script.

SCRIPT="${SCRIPT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/dot_local/bin/executable_jj-integrate}"

# Isolate the dev's global jj config so it can't mask behavior (e.g. a personal
# ui.diff-formatter or aliases). Identity still comes from mkrepo's --repo config.
_jji_iso="$(mktemp -d "${TMPDIR:-/tmp}/jji-cfg.XXXXXX")/config.toml"
: > "$_jji_iso"
export JJ_CONFIG="$_jji_iso"

# mkrepo — create a scratch jj repo under $TMPDIR and print its path.
mkrepo() {
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/jj-integrate-test.XXXXXX")"
  (
    cd "$dir"
    jj git init --quiet
    jj config set --repo user.name  "jj-integrate-test" 2>/dev/null
    jj config set --repo user.email "test@example.invalid" 2>/dev/null
  )
  printf '%s\n' "$dir"
}

# assert_eq expected actual [label]
assert_eq() {
  local expected=$1 actual=$2 label=${3:-value}
  if [[ "$expected" != "$actual" ]]; then
    printf 'ASSERTION FAILED: %s\n  expected: %q\n  actual:   %q\n' "$label" "$expected" "$actual" >&2
    return 1
  fi
}

# fail msg — print to stderr and return 1
fail() { printf 'FAIL: %s\n' "$*" >&2; return 1; }

# ── jj helpers ──────────────────────────────────────────────────────────────
cid()       { jj log --no-graph -r "$1" -T 'commit_id.short()' 2>/dev/null | head -n1; }
nparents()  { jj log --no-graph -r "$1-" -T '"x\n"' 2>/dev/null | grep -c x || true; }
has_parent(){ [[ -n "$(jj log --no-graph -r "$1- & $2" -T '"x"' 2>/dev/null)" ]]; }
exists()    { jj log --no-graph -r "$1" -T '""' >/dev/null 2>&1; }

# mkbase NAME — a base commit bookmarked NAME (default local/main).
mkbase() { echo base > base.txt && jj commit -m base 2>/dev/null; jj bookmark set "${1:-local/main}" -r @- 2>/dev/null; }

# mkwip NAME BASE FILE — a single-commit branch NAME off BASE adding FILE.
# FILE defaults to a slash-free name derived from NAME (wip/a -> wip_a.txt).
mkwip() {
  local name=$1 base=${2:-local/main} file=${3:-}
  [[ -n "$file" ]] || file="$(printf '%s' "$name" | tr '/' '_').txt"
  jj new "$base" 2>/dev/null
  echo "$name" > "$file" && jj commit -m "$name" 2>/dev/null
  jj bookmark set "$name" -r @- 2>/dev/null
}
