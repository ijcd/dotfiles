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

# first_parent_of REV — short commit id of REV's FIRST parent, order-preserving
# (the `-` operator returns parents unordered; a merge-forward prime commit has
# two). Mirrors the tool's internal first_parent for assertions.
first_parent_of() {
  jj log --no-graph -r "$1" -T 'parents.map(|p| p.commit_id().short()).join("\n") ++ "\n"' 2>/dev/null \
    | awk 'NF' | head -n1
}

# mk_divergent_thread — build a "stuck-stale" thread. local/main (source root)
# adds a top line to cfg, shifting line numbers, so wip/x's edit to a mid-file
# line rebuilds cleanly onto master (prime root) but its diff hunk header never
# byte-matches the source — a base divergence sync cannot resolve. Run inside a
# fresh `cd "$(mkrepo)"`.
mk_divergent_thread() {
  printf 'L1\nL2\nL3\nL4\ntarget=1\nL6\nL7\n' > cfg
  jj commit -m "master base" >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
  jj new master >/dev/null 2>&1
  printf 'LOCALHEADER\nL1\nL2\nL3\nL4\ntarget=1\nL6\nL7\n' > cfg
  jj commit -m "local personal tweak" >/dev/null 2>&1; jj bookmark set local/main -r @- >/dev/null 2>&1
  jj new local/main >/dev/null 2>&1
  printf 'LOCALHEADER\nL1\nL2\nL3\nL4\ntarget=2\nL6\nL7\n' > cfg
  jj commit -m "feat-x" >/dev/null 2>&1; jj bookmark set wip/x -r @- >/dev/null 2>&1
  jj new @- >/dev/null 2>&1
  jj config set --repo jj-mirror.source-root local/main >/dev/null 2>&1
  jj config set --repo jj-mirror.prime-root  master     >/dev/null 2>&1
}
