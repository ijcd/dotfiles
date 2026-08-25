# test/jj-cleanup/lib.sh — shared helpers for jj-cleanup tests.
source "$(dirname "${BASH_SOURCE[0]}")/../_jjflow_testwrap.sh"
SCRIPT="${SCRIPT:-$(flow_make_wrapper "jjflow-cleanup.sh" cleanup_main)}"

# Isolate the dev's global jj config.
_iso="$(mktemp -d "${TMPDIR:-/tmp}/jjclean-cfg.XXXXXX")/config.toml"; : > "$_iso"
export JJ_CONFIG="$_iso"

# Per-test stub bin, prepended to PATH. stub_cmd <name> <body> writes an executable.
stub_dir() { STUBBIN="$(mktemp -d "${TMPDIR:-/tmp}/jjclean-bin.XXXXXX")"; export PATH="$STUBBIN:$PATH"; }
stub_cmd() {
  local name=$1 body=$2
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$STUBBIN/$name"
  chmod +x "$STUBBIN/$name"
}

mkrepo() {
  local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/jj-clean-test.XXXXXX")"
  ( cd "$dir"
    jj git init --quiet
    jj config set --repo user.name  "jj-clean-test" 2>/dev/null
    jj config set --repo user.email "test@example.invalid" 2>/dev/null
    # local/main base with one personal commit, so wip/* stack on it.
    echo base > base.txt; jj commit -m base 2>/dev/null
    jj bookmark create local/main -r @- 2>/dev/null
  )
  printf '%s\n' "$dir"
}

# Make a wip/<suffix> workspace at <repo>/../<suffix> with n commits on local/main.
mkwip() { # <repo> <suffix> <n>
  local repo=$1 suffix=$2 n=$3 ws="${1%/}.$2" i
  jj workspace add --name "$suffix" "$ws" -r local/main >/dev/null 2>&1
  ( cd "$ws"
    for ((i=1;i<=n;i++)); do echo "$suffix$i" > "f_$suffix$i"; jj commit -m "$suffix$i" 2>/dev/null; done
    jj bookmark create "wip/$suffix" -r @- 2>/dev/null
  )
  # Canonicalize (macOS /var → /private/var) so it matches jj's reported root.
  ws="$(cd "$ws" && pwd -P)"
  printf '%s\n' "$ws"
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
countrev() { jj log --no-graph -r "$1" -T '"x\n"' 2>/dev/null | grep -c x; }
