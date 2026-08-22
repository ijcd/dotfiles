# test/jj-catch-up/lib.sh — shared helpers for the (new) catch-up suite.

BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/dot_local/bin"
SCRIPT="${SCRIPT:-$BIN/executable_jj-refresh-workspaces}"

mkrepo() {
  local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/jj-catchup-test.XXXXXX")"
  ( cd "$dir"; jj git init --quiet
    jj config set --repo user.name  "catchup-test"        2>/dev/null
    jj config set --repo user.email "test@example.invalid" 2>/dev/null )
  printf '%s\n' "$dir"
}

# asserts EXIT on failure (these tests run without set -e, so a return wouldn't
# stop the script — it would falsely report ok).
assert_eq() {
  local e=$1 a=$2 l=${3:-value}
  [[ "$e" == "$a" ]] || { printf 'ASSERTION FAILED: %s\n  expected: %q\n  actual:   %q\n' "$l" "$e" "$a" >&2; exit 1; }
}
assert_contains() {
  local h=$1 n=$2 l=${3:-contains}
  [[ "$h" == *"$n"* ]] || { printf 'ASSERTION FAILED: %s\n  expected to contain: %q\n  in: %q\n' "$l" "$n" "$h" >&2; exit 1; }
}
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

cid() { jj log --no-graph -r "$1" -T 'commit_id.short()' 2>/dev/null | head -n1; }
# is A an ancestor of B?
is_ancestor() { jj log --no-graph -r "$1 & ancestors($2)" -T '"y"' 2>/dev/null | grep -q y; }
