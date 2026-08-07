#!/usr/bin/env bash
# run-all — execute every test_*.sh in this directory. Exit non-zero on first failure.
set -euo pipefail
cd "$(dirname "$0")"

pass=0 fail=0
for t in test_*.sh; do
  [[ -f $t ]] || continue
  if bash "$t"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '  ^ %s failed\n' "$t" >&2
  fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
