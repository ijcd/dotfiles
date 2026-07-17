# test/jj-mirror/lib.sh — shared helpers for jj-mirror tests.
# Sourced by every test_*.sh script.

SCRIPT="${SCRIPT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/dot_local/bin/executable_jj-mirror}"

# mkrepo — create a scratch jj repo under $TMPDIR and print its path.
# The caller MUST `cd` into the path — mkrepo runs setup in a subshell so its
# own `cd` doesn't leak, and is typically called as `repo="$(mkrepo)"`, which
# runs mkrepo in a subshell too. The caller cleans up (the run-all script does).
#
# Usage:
#   repo="$(mkrepo)"
#   cd "$repo"
mkrepo() {
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/jj-mirror-test.XXXXXX")"
  (
    cd "$dir"
    jj git init --quiet
    # jj config set emits a benign "future commits only" warning for user.name/email; silence it.
    jj config set --repo user.name  "jj-mirror-test" 2>/dev/null
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
