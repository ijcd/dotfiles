# test/jj-flow/lib.sh — shared helpers for jj-flow tests. Sourced by every test_*.sh.

BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/dot_local/bin"
SCRIPT="${SCRIPT:-$BIN/executable_jj-flow}"

# mkrepo — scratch jj repo under $TMPDIR; caller cds in and cleans up.
mkrepo() {
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/jj-flow-test.XXXXXX")"
  (
    cd "$dir"
    jj git init --quiet
    jj config set --repo user.name  "jj-flow-test" 2>/dev/null
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

# assert_contains haystack needle [label]
assert_contains() {
  local haystack=$1 needle=$2 label=${3:-contains}
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'ASSERTION FAILED: %s\n  expected to contain: %q\n  in:\n%s\n' "$label" "$needle" "$haystack" >&2
    return 1
  fi
}

fail() { printf 'FAIL: %s\n' "$*" >&2; return 1; }

# mk_layers — the standard private-stack shape: master(trunk) ← local/main ← the
# caller's wip branches. Leaves @ on a fresh child of local/main. Sets the
# jj-flow trunk/base config so trunk()=master and base=local/main.
mk_layers() {
  printf 'trunk\n' > f; jj commit -m M0 >/dev/null 2>&1; jj bookmark set master -r @- >/dev/null 2>&1
  jj new master >/dev/null 2>&1
  echo localonly > localonly; jj commit -m "local base" >/dev/null 2>&1
  jj bookmark set local/main -r @- >/dev/null 2>&1
  jj new local/main >/dev/null 2>&1
  jj config set --repo jj-mirror.source-root local/main >/dev/null 2>&1
  jj config set --repo jj-mirror.prime-root  master     >/dev/null 2>&1
}
