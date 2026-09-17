#!/usr/bin/env bash
# test_push_verbose — push marks the sync->jj-vine phase boundary and invokes jj-vine with
# -v, so an agent watching the otherwise-silent GitHub round-trip can tell working from
# hung. Also the first coverage of the push SUCCESS path (test_push covers only not-found).
# Stubs a fake jj-vine that records its args, emits output, and exits with a distinctive
# code so exit-code propagation through the exec is checked too.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

repo="$(mkrepo)"; cd "$repo"
echo a1 > f && jj commit -m a1 >/dev/null 2>&1; jj bookmark set wip/a1 -r @- >/dev/null 2>&1

tmpbin="$(mktemp -d)"; argfile="$tmpbin/args"
cat > "$tmpbin/jj-vine" <<EOF
#!/bin/bash
printf '%s ' "\$@" > "$argfile"
echo "fake-vine: pushing bookmarks…"
exit 7
EOF
chmod +x "$tmpbin/jj-vine"
# Sandbox PATH so the fake jj-vine wins; keep jj + coreutils. Drop user jj config so a
# `vine` alias can't shadow the binary lookup (same reasoning as test_push).
export PATH="$tmpbin:$(command -v jj | xargs dirname):/usr/bin:/bin"
export JJ_CONFIG="$tmpbin/empty.toml"; : > "$JJ_CONFIG"

set +e
out="$("$SCRIPT" push 2>&1)"; rc=$?
set -e

[[ $rc -eq 7 ]] || fail "jj-vine exit code not propagated through exec (got $rc, want 7)"
[[ "$out" == *"handing to jj-vine"* ]] || fail "phase-boundary marker not printed: $out"
[[ "$out" == *"fake-vine: pushing"* ]] || fail "jj-vine output did not reach the user: $out"
grep -q -- '-v'        "$argfile" || fail "jj-vine not invoked with -v (args: $(cat "$argfile"))"
grep -q -- '--tracked' "$argfile" || fail "jj-vine not invoked with --tracked (args: $(cat "$argfile"))"

cd / && rm -rf "$repo" "$tmpbin"
echo "ok: push_verbose"
