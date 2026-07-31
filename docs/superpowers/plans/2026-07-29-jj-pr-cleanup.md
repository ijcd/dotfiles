# jj-pr-cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tear down everything a merged/closed PR leaves behind — local + remote bookmarks, jj workspace, its directory, its kitty tab — parking any unmerged work under `todo/<name>` first, confirming before mutating.

**Architecture:** A tested bash tool `jj-cleanup` (subcommands `scan` read-only, `teardown` destructive) plus a `jj-pr-cleanup` skill that drives scan → present → confirm → teardown. Detection is squash-safe: `gh` for merged/closed status, prime-count vs wip-thread-count for the unmerged tail. All work happens in the `local/main..wip/<suffix>` window; `local/main` and below are untouchable.

**Tech Stack:** bash, jj (jujutsu) 0.43, `gh` CLI, kitty remote control. Tests are fixture-based bash (pattern from `test/jj-tug/`, `test/jj-mirror/`).

## Global Constraints

- **Base window is always `local/main..wip/<suffix>`** — resolve base as `local/main` if it exists, else `trunk()` (mirrors jj-mirror's `coalesce(present(local/main), trunk())`). Never `trunk()..`.
- **`trunk()` = `master@origin`.** Prefixes: source `wip/`, prime `ijcd/`, park `todo/`.
- **Denylist (never touched):** workspaces `default` and `local-main`; bookmark `local/main`.
- **Squash-safe:** merged status only from `gh mergedAt`; never per-commit SHA/patch matching.
- **`ijcd/<suffix>` head branches only** — PR lookup keys off that name; other heads out of scope.
- External commands invoked by bare name (`gh`, `kitty`, `jj`) so tests stub via `PATH`.
- chezmoi source prefixes: tool is `dot_local/bin/executable_jj-cleanup` → `~/.local/bin/jj-cleanup` (+x). Skill dir `private_dot_claude/skills/jj-pr-cleanup/` → `~/.claude/skills/jj-pr-cleanup/` (already tracked via `.chezmoiignore`'s `!.claude/skills`).
- Every `test_*.sh` starts `set -euo pipefail` + `source "$(dirname "$0")/lib.sh"`, ends by removing temp dirs and printing `ok: <name>`.

---

### Task 1: Tool skeleton, dispatch, help, test harness

**Files:**
- Create: `dot_local/bin/executable_jj-cleanup`
- Create: `test/jj-cleanup/lib.sh`
- Create: `test/jj-cleanup/run-all.sh`
- Test: `test/jj-cleanup/test_help.sh`

**Interfaces:**
- Produces: `jj-cleanup` dispatch — subcommands `scan` (default), `teardown`, `help`. Unknown subcommand → usage on stderr, exit 2.

- [ ] **Step 1: Write the failing test** — `test/jj-cleanup/test_help.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

out="$("$SCRIPT" help 2>&1)"
[[ "$out" == *scan* && "$out" == *teardown* ]] || fail "help must list scan + teardown"

# unknown subcommand → exit 2
if "$SCRIPT" bogus >/dev/null 2>&1; then fail "unknown subcommand should exit non-zero"; fi
rc=0; "$SCRIPT" bogus >/dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "unknown subcommand exit code"

echo "ok: help"
```

- [ ] **Step 2: Create `test/jj-cleanup/lib.sh`** (harness; extends the jj-tug pattern with a stub-bin on PATH)

```bash
# test/jj-cleanup/lib.sh — shared helpers for jj-cleanup tests.
SCRIPT="${SCRIPT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/dot_local/bin/executable_jj-cleanup}"

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
```

- [ ] **Step 3: Create `test/jj-cleanup/run-all.sh`** (copy of the jj-tug runner)

```bash
#!/usr/bin/env bash
# run-all — execute every test_*.sh in this directory. Exit non-zero on first failure.
set -euo pipefail
cd "$(dirname "$0")"
pass=0 fail=0
for t in test_*.sh; do
  [[ -f $t ]] || continue
  if bash "$t"; then pass=$((pass + 1)); else fail=$((fail + 1)); printf '  ^ %s failed\n' "$t" >&2; fi
done
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
```
Then `chmod +x test/jj-cleanup/run-all.sh`.

- [ ] **Step 4: Run test to verify it fails**

Run: `bash test/jj-cleanup/test_help.sh`
Expected: FAIL — `$SCRIPT` doesn't exist yet.

- [ ] **Step 5: Write minimal `dot_local/bin/executable_jj-cleanup`**

```bash
#!/usr/bin/env bash
# jj-cleanup — tear down a merged/closed PR's bookmarks, workspace, dir, kitty tab.
# See docs/superpowers/plans/2026-07-29-jj-pr-cleanup.md and the jj-pr-cleanup skill.
set -uo pipefail

usage() {
  cat <<'EOF'
jj-cleanup — clean up after a merged/closed PR (lunar wip/* → ijcd/* model)

  jj-cleanup scan                     list workspaces + PR state + would-be-lost (read-only)
  jj-cleanup teardown <suffix> [opts] tear down one workspace
      --park todo/<name>              park unmerged tail under this bookmark
      --dry-run                       print commands, mutate nothing
  jj-cleanup help

Never touches: default/local-main workspaces, local/main bookmark.
EOF
}

main() {
  local cmd="${1:-scan}"; shift || true
  case "$cmd" in
    scan)     cmd_scan "$@";;
    teardown) cmd_teardown "$@";;
    help|-h|--help) usage;;
    *) usage >&2; return 2;;
  esac
}

# Stubs filled in by later tasks.
cmd_scan()     { :; }
cmd_teardown() { :; }

main "$@"
```
Then `chmod +x dot_local/bin/executable_jj-cleanup`.

- [ ] **Step 6: Run test to verify it passes**

Run: `bash test/jj-cleanup/test_help.sh`
Expected: PASS → `ok: help`

- [ ] **Step 7: Commit**

```bash
git add dot_local/bin/executable_jj-cleanup test/jj-cleanup/
git commit -m "jj-cleanup: skeleton + dispatch + test harness"
```

---

### Task 2: Base resolution + workspace enumeration (with denylist)

**Files:**
- Modify: `dot_local/bin/executable_jj-cleanup`
- Test: `test/jj-cleanup/test_workspaces.sh`

**Interfaces:**
- Produces:
  - `resolve_base` → prints `local/main` if that bookmark exists, else `trunk()`.
  - `list_workspaces` → prints `name\troot` lines, one per workspace, EXCLUDING `default` and `local-main`, and excluding rows whose root is missing/`<Error…>`.

- [ ] **Step 1: Write the failing test** — `test/jj-cleanup/test_workspaces.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" alpha 2)"
wsB="$(mkwip "$repo" beta 1)"

# resolve_base sees local/main
assert_eq "local/main" "$("$SCRIPT" __test_resolve_base)" "base is local/main"

# list_workspaces yields alpha + beta, NOT default
out="$("$SCRIPT" __test_list_workspaces)"
[[ "$out" == *alpha* && "$out" == *beta* ]] || fail "must list alpha + beta: $out"
[[ "$out" != *"	"*default* ]] || true   # default is denylisted
grep -q '^default	' <<<"$out" && fail "default must be excluded"
grep -q "$wsA" <<<"$out" || fail "alpha root path present"

cd / && rm -rf "$repo" "$wsA" "$wsB"; echo "ok: workspaces"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/jj-cleanup/test_workspaces.sh`
Expected: FAIL — `__test_resolve_base` unknown subcommand (exit 2) / no output.

- [ ] **Step 3: Implement** — add helpers + test hooks to `executable_jj-cleanup`

Add above `main()`:
```bash
DENY_WS="default local-main"

resolve_base() {
  if jj log --no-graph -r 'present(local/main)' -T '""' >/dev/null 2>&1 \
     && [[ -n "$(jj log --no-graph -r 'present(local/main)' -T '"x"' 2>/dev/null)" ]]; then
    printf 'local/main\n'
  else
    printf 'trunk()\n'
  fi
}

list_workspaces() {
  # name<TAB>root; drop denylisted + broken roots.
  jj workspace list --ignore-working-copy -T 'name ++ "\t" ++ root ++ "\n"' 2>/dev/null \
  | while IFS=$'\t' read -r name root; do
      [[ -n "$name" ]] || continue
      case " $DENY_WS " in *" $name "*) continue;; esac
      [[ -n "$root" && "$root" != *"<Error"* && -d "$root" ]] || continue
      printf '%s\t%s\n' "$name" "$root"
    done
}
```
Add cases to the `main()` dispatch `case`:
```bash
    __test_resolve_base)    resolve_base;;
    __test_list_workspaces) list_workspaces;;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/jj-cleanup/test_workspaces.sh`
Expected: PASS → `ok: workspaces`

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/executable_jj-cleanup test/jj-cleanup/test_workspaces.sh
git commit -m "jj-cleanup: base resolution + workspace enumeration (denylist)"
```

---

### Task 3: PR-state detection via `gh` (stubbed)

**Files:**
- Modify: `dot_local/bin/executable_jj-cleanup`
- Test: `test/jj-cleanup/test_pr_state.sh`

**Interfaces:**
- Produces: `pr_state <suffix>` → prints one of `MERGED`, `CLOSED`, `OPEN`, `NONE` (no PR found), `ERROR` (gh failed). Calls `gh pr view "ijcd/<suffix>" --json state,mergedAt`. Eligible-for-teardown = `MERGED` or `CLOSED`.

- [ ] **Step 1: Write the failing test** — `test/jj-cleanup/test_pr_state.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stub_dir
repo="$(mkrepo)"; cd "$repo"

# gh stub: reads branch from args, maps via $FAKE. "MERGED@time" | "OPEN" | exits 1 for none/error.
stub_cmd gh '
br="";
for a in "$@"; do case "$a" in ijcd/*) br="$a";; esac; done
case "$FAKE" in
  merged) echo "{\"state\":\"MERGED\",\"mergedAt\":\"2026-07-20T00:00:00Z\"}";;
  open)   echo "{\"state\":\"OPEN\",\"mergedAt\":null}";;
  none)   echo "no pull requests found" >&2; exit 1;;
esac'

FAKE=merged assert_eq MERGED "$("$SCRIPT" __test_pr_state feat)" "merged PR"
FAKE=open   assert_eq OPEN   "$("$SCRIPT" __test_pr_state feat)" "open PR"
FAKE=none   assert_eq NONE   "$("$SCRIPT" __test_pr_state feat)" "no PR"

cd / && rm -rf "$repo"; echo "ok: pr_state"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/jj-cleanup/test_pr_state.sh`
Expected: FAIL — `__test_pr_state` unknown.

- [ ] **Step 3: Implement** — add to `executable_jj-cleanup`

```bash
pr_state() { # <suffix>
  local suffix=$1 json state
  json="$(gh pr view "ijcd/$suffix" --json state,mergedAt 2>/dev/null)" || { printf 'NONE\n'; return; }
  [[ -n "$json" ]] || { printf 'NONE\n'; return; }
  # jq-free extract: state is a quoted word.
  state="$(printf '%s' "$json" | sed -n 's/.*"state":"\([A-Z]*\)".*/\1/p')"
  case "$state" in MERGED|CLOSED|OPEN) printf '%s\n' "$state";; *) printf 'ERROR\n';; esac
}
```
Dispatch case: `__test_pr_state) pr_state "$@";;`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/jj-cleanup/test_pr_state.sh`
Expected: PASS → `ok: pr_state`

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/executable_jj-cleanup test/jj-cleanup/test_pr_state.sh
git commit -m "jj-cleanup: PR-state detection via gh"
```

---

### Task 4: Would-be-lost detection (unmerged tail + uncommitted @)

**Files:**
- Modify: `dot_local/bin/executable_jj-cleanup`
- Test: `test/jj-cleanup/test_lost.sh`

**Interfaces:**
- Produces:
  - `prime_count <suffix>` → `countrev "trunk()..ijcd/<suffix>"`, or empty string if `ijcd/<suffix>` bookmark absent.
  - `lost_tail_root <suffix>` → prints the commit_id of the unmerged tail's root (the `(prime_count)`-th thread commit from the bottom, 0-indexed = first unmerged), or empty if nothing lost. Requires the local `ijcd/<suffix>` bookmark; prints sentinel `NOPRIME` if absent.
  - `ws_dirty <name>` → exit 0 if that workspace's `@` has a non-empty diff (uncommitted work), else exit 1.

Detection rule (Global Constraints): thread = `<base>..wip/<suffix>` (base from `resolve_base`). Merged portion size = `prime_count`. Lost = thread commits beyond that, positionally from the bottom (mirror maps bottom-up 1:1). No SHA matching.

- [ ] **Step 1: Write the failing test** — `test/jj-cleanup/test_lost.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 3)"   # 3 commits on local/main: feat1,feat2,feat3

# Simulate a prime that captured only the first 2 (feat1,feat2): a 2-commit chain on trunk-ish.
# Here trunk()=root's default; emulate by pointing ijcd/feat at a 2-deep chain off local/main.
base="$(cid local/main)"
c1="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 1p)"
c2="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 2p)"
jj bookmark create ijcd/feat -r "$c2" 2>/dev/null   # prime = 2 commits deep

# prime_count counts trunk()..ijcd/feat. With trunk()=root(), that includes base+c1+c2=3.
# So the plan's count uses <base>..ijcd/feat semantics — verify against base instead:
pc="$(countrev "local/main..ijcd/feat")"
assert_eq 2 "$pc" "prime holds 2 commits over base"

# lost_tail_root = 3rd thread commit (index 2) = feat3's id
root="$("$SCRIPT" __test_lost_tail_root feat)"
c3="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 3p)"
assert_eq "$c3" "$root" "lost tail root is feat3"

# Fully-merged case: prime captures all 3 → no lost tail.
jj bookmark set ijcd/feat -r "$(cid wip/feat)" 2>/dev/null
assert_eq "" "$("$SCRIPT" __test_lost_tail_root feat)" "nothing lost when prime == wip"

cd / && rm -rf "$repo" "$wsA"; echo "ok: lost"
```
> NOTE to implementer: `prime_count`/`lost_tail_root` count over `<base>..ijcd/<suffix>` (base from `resolve_base`), NOT `trunk()..`, so the fixture doesn't need a configured `master@origin`. The spec's "`trunk()..ijcd`" describes the deployed repo where prime-root IS `master`; using `<base>..` here is equivalent for counting the prime's own commits and keeps tests hermetic. Document this in a code comment.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/jj-cleanup/test_lost.sh`
Expected: FAIL — `__test_lost_tail_root` unknown.

- [ ] **Step 3: Implement** — add to `executable_jj-cleanup`

```bash
# Prime commit count = commits the mirror captured (== what the PR contained).
# Counted over <base>..ijcd/<suffix> (base = resolve_base), matching how the
# thread itself is measured; equivalent to trunk()..ijcd where prime-root=master.
prime_count() { # <suffix>
  local s=$1 base; base="$(resolve_base)"
  exists "ijcd/$s" || { printf ''; return; }
  countrev "$base..ijcd/$s"
}

lost_tail_root() { # <suffix> -> commit_id of first unmerged thread commit, or ""/NOPRIME
  local s=$1 base pc n; base="$(resolve_base)"
  exists "ijcd/$s" || { printf 'NOPRIME\n'; return; }
  pc="$(prime_count "$s")"; n="$(countrev "$base..wip/$s")"
  (( n > pc )) || { printf ''; return; }               # nothing beyond the prime
  # Thread commits bottom->top; index pc (0-based) is the first unmerged one.
  jj log --no-graph -r "$base..wip/$s" --reversed -T 'commit_id ++ "\n"' 2>/dev/null \
    | sed -n "$((pc + 1))p"
}

ws_dirty() { # <name>  -> exit 0 if that workspace @ has uncommitted diff
  local name=$1
  [[ -n "$(jj diff --ignore-working-copy -r "${name}@" --stat 2>/dev/null)" ]]
}
```
Dispatch cases:
```bash
    __test_prime_count)    prime_count "$@";;
    __test_lost_tail_root) lost_tail_root "$@";;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/jj-cleanup/test_lost.sh`
Expected: PASS → `ok: lost`

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/executable_jj-cleanup test/jj-cleanup/test_lost.sh
git commit -m "jj-cleanup: would-be-lost detection (unmerged tail + dirty @)"
```

---

### Task 5: `scan` command (compose the table)

**Files:**
- Modify: `dot_local/bin/executable_jj-cleanup`
- Test: `test/jj-cleanup/test_scan.sh`

**Interfaces:**
- Consumes: `list_workspaces`, `pr_state`, `lost_tail_root`, `resolve_base`, `countrev`.
- Produces: `cmd_scan` prints a header + one row per workspace: `<suffix>  <PR state>  ijcd:<yes|no>  lost:<n>  tab:<cc-name>`. Read-only (no `jj git fetch` in tests — gate it behind `--fetch`, default off, so tests are hermetic; the skill passes `--fetch`).

- [ ] **Step 1: Write the failing test** — `test/jj-cleanup/test_scan.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stub_dir
stub_cmd gh 'echo "{\"state\":\"MERGED\",\"mergedAt\":\"2026-07-20T00:00:00Z\"}"'
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 2)"
jj bookmark create ijcd/feat -r "$(cid wip/feat)" 2>/dev/null   # fully mirrored → lost:0

out="$("$SCRIPT" scan 2>&1)"
grep -q '^feat' <<<"$out" || fail "row for feat: $out"
[[ "$out" == *MERGED* ]] || fail "shows MERGED"
[[ "$out" == *lost:0* ]] || fail "shows lost:0"
grep -q '^default' <<<"$out" && fail "default must not appear"

cd / && rm -rf "$repo" "$wsA"; echo "ok: scan"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/jj-cleanup/test_scan.sh`
Expected: FAIL — `cmd_scan` is still a stub (`:`).

- [ ] **Step 3: Implement** — replace the `cmd_scan` stub

```bash
cmd_scan() {
  [[ "${1:-}" == "--fetch" ]] && jj git fetch >/dev/null 2>&1
  printf '%-28s %-8s %-9s %-7s %s\n' SUFFIX PR IJCD LOST TAB
  local base; base="$(resolve_base)"
  list_workspaces | while IFS=$'\t' read -r name root; do
    local ps ijcd nlost tabname
    ps="$(pr_state "$name")"
    ijcd=no; exists "ijcd/$name" && ijcd=yes
    if [[ "$ijcd" == yes ]]; then
      local n pc; n="$(countrev "$base..wip/$name")"; pc="$(prime_count "$name")"
      nlost=$(( n > pc ? n - pc : 0 ))
    else nlost='?'; fi
    ws_dirty "$name" && nlost="${nlost}+dirty"
    tabname="cc:$name"
    printf '%-28s %-8s %-9s %-7s %s\n' "$name" "$ps" "ijcd:$ijcd" "lost:$nlost" "$tabname"
  done
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/jj-cleanup/test_scan.sh`
Expected: PASS → `ok: scan`

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/executable_jj-cleanup test/jj-cleanup/test_scan.sh
git commit -m "jj-cleanup: scan command (workspace/PR/lost table)"
```

---

### Task 6: Parking the unmerged tail under `todo/<name>`

**Files:**
- Modify: `dot_local/bin/executable_jj-cleanup`
- Test: `test/jj-cleanup/test_park.sh`

**Interfaces:**
- Consumes: `lost_tail_root`, `resolve_base`.
- Produces: `do_park <suffix> <todo-name>` → rebases the unmerged tail onto `<base>` (dropping the merged-and-squashed middle) and creates bookmark `<todo-name>` at the rebased tip. No-op (exit 0, prints `park: nothing to park`) when `lost_tail_root` is empty. Refuses (exit 1) on `NOPRIME`.

- [ ] **Step 1: Write the failing test** — `test/jj-cleanup/test_park.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 3)"
c1="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 1p)"
c2="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 2p)"
jj bookmark create ijcd/feat -r "$c2" 2>/dev/null   # merged = feat1,feat2; lost = feat3

"$SCRIPT" __test_do_park feat todo/keep-feat3

exists todo/keep-feat3 || fail "todo bookmark created"
# todo/keep-feat3 sits directly on local/main (merged middle dropped): its only
# thread commit over base is feat3 → count == 1.
assert_eq 1 "$(countrev "local/main..todo/keep-feat3")" "parked tail is 1 commit on base"
# base intact
exists local/main || fail "local/main survived"

cd / && rm -rf "$repo" "$wsA"; echo "ok: park"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/jj-cleanup/test_park.sh`
Expected: FAIL — `__test_do_park` unknown.

- [ ] **Step 3: Implement** — add to `executable_jj-cleanup`

```bash
do_park() { # <suffix> <todo-name>
  local s=$1 todo=$2 base root; base="$(resolve_base)"
  root="$(lost_tail_root "$s")"
  [[ "$root" != NOPRIME ]] || { echo "park: no local ijcd/$s prime — refusing to guess" >&2; return 1; }
  [[ -n "$root" ]] || { echo "park: nothing to park"; return 0; }
  # Detach the tail (root + descendants within the thread) onto base, dropping the
  # merged middle; then bookmark the rebased tip (== wip/<suffix>'s new location).
  jj rebase -s "$root" -d "$base" >/dev/null 2>&1
  jj bookmark create "$todo" -r "wip/$s" >/dev/null 2>&1
}
```
Dispatch case: `__test_do_park) do_park "$@";;`
> Comment for implementer: after `jj rebase -s root -d base`, `wip/<suffix>` follows its commits to the new location, so `-r wip/$s` is the rebased tip.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/jj-cleanup/test_park.sh`
Expected: PASS → `ok: park`

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/executable_jj-cleanup test/jj-cleanup/test_park.sh
git commit -m "jj-cleanup: park unmerged tail under todo/<name> on base"
```

---

### Task 7: Local teardown steps — bookmarks, forget workspace, rm dir (guarded)

**Files:**
- Modify: `dot_local/bin/executable_jj-cleanup`
- Test: `test/jj-cleanup/test_teardown_local.sh`
- Test: `test/jj-cleanup/test_rm_guard.sh`

**Interfaces:**
- Produces:
  - `del_bookmarks <suffix>` → `jj bookmark delete wip/<suffix> ijcd/<suffix>` (tolerate absent).
  - `forget_ws <name>` → `jj workspace forget <name>` (tolerate absent).
  - `rm_ws_dir <root>` → `rm -rf` **only if** `$root` resolves under `~/work/lunar/` AND contains `.jj`; else exit 1 + message. A `JJ_CLEANUP_WS_ROOT` env var overrides the `~/work/lunar` prefix (tests set it to their temp root).

- [ ] **Step 1: Write the failing tests**

`test/jj-cleanup/test_teardown_local.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 1)"
jj bookmark create ijcd/feat -r "$(cid wip/feat)" 2>/dev/null

"$SCRIPT" __test_del_bookmarks feat
exists wip/feat  && fail "wip/feat deleted"
exists ijcd/feat && fail "ijcd/feat deleted"

"$SCRIPT" __test_forget_ws feat
jj workspace list --ignore-working-copy -T 'name ++ "\n"' | grep -q '^feat$' && fail "workspace forgotten"

cd / && rm -rf "$repo" "$wsA"; echo "ok: teardown_local"
```

`test/jj-cleanup/test_rm_guard.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# refuse: not a jj workspace dir
bad="$(mktemp -d "${TMPDIR:-/tmp}/notjj.XXXXXX")"
if JJ_CLEANUP_WS_ROOT="$bad" "$SCRIPT" __test_rm_ws_dir "$bad" 2>/dev/null; then fail "must refuse non-.jj dir"; fi
[[ -d "$bad" ]] || fail "dir must survive refusal"

# refuse: outside the allowed root prefix
out="$(mktemp -d "${TMPDIR:-/tmp}/outside.XXXXXX")"; mkdir -p "$out/.jj"
if JJ_CLEANUP_WS_ROOT="/nonexistent/prefix" "$SCRIPT" __test_rm_ws_dir "$out" 2>/dev/null; then fail "must refuse outside prefix"; fi
[[ -d "$out" ]] || fail "outside dir must survive"

# accept: under allowed root AND has .jj
good="$(mktemp -d "${TMPDIR:-/tmp}/wsroot.XXXXXX")"; mkdir -p "$good/ws/.jj"
JJ_CLEANUP_WS_ROOT="$good" "$SCRIPT" __test_rm_ws_dir "$good/ws" || fail "should remove valid ws dir"
[[ ! -d "$good/ws" ]] || fail "valid ws dir removed"

rm -rf "$bad" "$out" "$good"; echo "ok: rm_guard"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash test/jj-cleanup/test_teardown_local.sh` and `bash test/jj-cleanup/test_rm_guard.sh`
Expected: FAIL — helpers unknown.

- [ ] **Step 3: Implement** — add to `executable_jj-cleanup`

```bash
del_bookmarks() { # <suffix>
  local s=$1
  jj bookmark delete "wip/$s"  >/dev/null 2>&1 || true
  jj bookmark delete "ijcd/$s" >/dev/null 2>&1 || true
}
forget_ws() { jj workspace forget "$1" >/dev/null 2>&1 || true; }

rm_ws_dir() { # <root>
  local root=$1 prefix="${JJ_CLEANUP_WS_ROOT:-$HOME/work/lunar}" real
  real="$(cd "$root" 2>/dev/null && pwd -P)" || { echo "rm: $root gone" >&2; return 0; }
  case "$real/" in "$prefix"/*) :;; *) echo "rm: refusing $real (outside $prefix)" >&2; return 1;; esac
  [[ -d "$real/.jj" ]] || { echo "rm: refusing $real (no .jj workspace marker)" >&2; return 1; }
  rm -rf "$real"
}
```
Dispatch cases:
```bash
    __test_del_bookmarks) del_bookmarks "$@";;
    __test_forget_ws)     forget_ws "$@";;
    __test_rm_ws_dir)     rm_ws_dir "$@";;
```

- [ ] **Step 4: Run tests to verify they pass**

Run both; Expected: `ok: teardown_local`, `ok: rm_guard`.

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/executable_jj-cleanup test/jj-cleanup/test_teardown_local.sh test/jj-cleanup/test_rm_guard.sh
git commit -m "jj-cleanup: local teardown (bookmarks, forget ws, guarded rm)"
```

---

### Task 8: Remote branch delete + kitty tab close (stubbed)

**Files:**
- Modify: `dot_local/bin/executable_jj-cleanup`
- Test: `test/jj-cleanup/test_remote_delete.sh`
- Test: `test/jj-cleanup/test_close_tab.sh`

**Interfaces:**
- Produces:
  - `del_remote <suffix>` → deletes `ijcd/<suffix>` on `origin`, tolerating already-deleted (`jj git push --deleted --bookmark "ijcd/<suffix>"`; on failure, no-op + note).
  - `close_tab <suffix> <root>` → via `kitty @ ls`, close tabs whose title == `cc:<suffix>` OR whose active window `cwd` is under `<root>`. No-op if `KITTY_LISTEN_ON` unset. Uses `kitty @ close-tab --match ...`.

- [ ] **Step 1: Write the failing tests**

`test/jj-cleanup/test_remote_delete.sh` (real local bare remote):
```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
bare="$(mktemp -d "${TMPDIR:-/tmp}/bare.XXXXXX")/o.git"; git init --bare -q "$bare"
jj git remote add origin "$bare" 2>/dev/null
jj bookmark create ijcd/feat -r 'local/main' 2>/dev/null
jj git push --allow-new --bookmark ijcd/feat >/dev/null 2>&1
git --git-dir="$bare" show-ref --verify -q refs/heads/ijcd/feat || fail "precondition: remote branch exists"

"$SCRIPT" __test_del_remote feat
git --git-dir="$bare" show-ref --verify -q refs/heads/ijcd/feat && fail "remote branch must be deleted"

# tolerate already-gone: second call must not error
"$SCRIPT" __test_del_remote feat || fail "second delete must be tolerant"

cd / && rm -rf "$repo" "$bare"; echo "ok: remote_delete"
```

`test/jj-cleanup/test_close_tab.sh` (kitty stub records close calls):
```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
stub_dir
calls="$(mktemp "${TMPDIR:-/tmp}/kittycalls.XXXXXX")"
export KITTY_LISTEN_ON="unix:/tmp/fake"
stub_cmd kitty '
if [[ "$1" == "@" && "$2" == "ls" ]]; then
  echo "[{\"tabs\":[{\"title\":\"cc:feat\",\"id\":7}]}]"; exit 0; fi
if [[ "$1" == "@" && "$2" == "close-tab" ]]; then echo "close-tab $*" >> "'"$calls"'"; exit 0; fi'

"$SCRIPT" __test_close_tab feat /tmp/whatever
grep -q 'close-tab' "$calls" || fail "should have closed the cc:feat tab"

# KITTY_LISTEN_ON unset → no-op, no error
unset KITTY_LISTEN_ON
: > "$calls"
"$SCRIPT" __test_close_tab feat /tmp/whatever || fail "no-op when not in kitty"
[[ ! -s "$calls" ]] || fail "must not call kitty when KITTY_LISTEN_ON unset"

rm -f "$calls"; echo "ok: close_tab"
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — helpers unknown.

- [ ] **Step 3: Implement** — add to `executable_jj-cleanup`

```bash
del_remote() { # <suffix>
  local s=$1
  jj git push --deleted --bookmark "ijcd/$s" >/dev/null 2>&1 \
    || echo "remote: ijcd/$s already gone or push skipped" >&2
  return 0
}

close_tab() { # <suffix> <root>
  local s=$1 root=$2 title="cc:$1"
  [[ -n "${KITTY_LISTEN_ON:-}" ]] || return 0
  # Close by title match (cheap, exact). cwd fallback left to the skill if needed.
  kitty @ ls >/dev/null 2>&1 || return 0
  kitty @ close-tab --match "title:^${title}$" >/dev/null 2>&1 || true
  return 0
}
```
Dispatch cases:
```bash
    __test_del_remote) del_remote "$@";;
    __test_close_tab)  close_tab "$@";;
```
> Implementer note: `--match "title:^cc:feat$"` uses kitty's match syntax. The stub accepts any `close-tab` args; the deployed kitty filters by the regex. If `kitty @ ls` shows no matching tab, `close-tab` is a tolerated no-op.

- [ ] **Step 4: Run tests to verify they pass**

Expected: `ok: remote_delete`, `ok: close_tab`.

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/executable_jj-cleanup test/jj-cleanup/test_remote_delete.sh test/jj-cleanup/test_close_tab.sh
git commit -m "jj-cleanup: remote branch delete + kitty tab close"
```

---

### Task 9: `teardown` command — ordered composition, `--park`, `--dry-run`

**Files:**
- Modify: `dot_local/bin/executable_jj-cleanup`
- Test: `test/jj-cleanup/test_teardown_order.sh`
- Test: `test/jj-cleanup/test_dry_run.sh`

**Interfaces:**
- Consumes: `do_park`, `del_bookmarks`, `del_remote`, `forget_ws`, `rm_ws_dir`, `close_tab`, `list_workspaces` (to map suffix→root), denylist.
- Produces: `cmd_teardown <suffix> [--park todo/<name>] [--dry-run]`. Order: **park → del_bookmarks → del_remote → forget_ws → rm_ws_dir → close_tab**. Refuses denylisted suffixes. `--dry-run` prints each command prefixed `DRYRUN:` and mutates nothing.

- [ ] **Step 1: Write the failing tests**

`test/jj-cleanup/test_teardown_order.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 3)"
c2="$(jj log --no-graph -r "local/main..wip/feat" --reversed -T 'commit_id ++ "\n"' | sed -n 2p)"
jj bookmark create ijcd/feat -r "$c2" 2>/dev/null   # feat3 unmerged → must be parked

JJ_CLEANUP_WS_ROOT="$(dirname "$wsA")" "$SCRIPT" teardown feat --park todo/keep-feat3

exists todo/keep-feat3 || fail "park happened before wip delete"
exists wip/feat  && fail "wip/feat deleted"
exists ijcd/feat && fail "ijcd/feat deleted"
[[ ! -d "$wsA" ]] || fail "workspace dir removed"

# denylist refusal
rc=0; "$SCRIPT" teardown default >/dev/null 2>&1 || rc=$?
[[ "$rc" -ne 0 ]] || fail "must refuse default"

cd / && rm -rf "$repo" "$wsA"; echo "ok: teardown_order"
```

`test/jj-cleanup/test_dry_run.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
wsA="$(mkwip "$repo" feat 2)"
jj bookmark create ijcd/feat -r "$(cid wip/feat)" 2>/dev/null

out="$(JJ_CLEANUP_WS_ROOT="$(dirname "$wsA")" "$SCRIPT" teardown feat --dry-run 2>&1)"
[[ "$out" == *DRYRUN* ]] || fail "dry-run prints DRYRUN lines"
exists wip/feat || fail "dry-run must NOT delete wip/feat"
[[ -d "$wsA" ]] || fail "dry-run must NOT remove dir"

cd / && rm -rf "$repo" "$wsA"; echo "ok: dry_run"
```

- [ ] **Step 2: Run tests to verify they fail**

Run both; Expected: FAIL — `cmd_teardown` is still a stub.

- [ ] **Step 3: Implement** — replace the `cmd_teardown` stub

```bash
cmd_teardown() {
  local suffix="" park="" dry=0
  while (( $# )); do
    case "$1" in
      --park) park="$2"; shift 2;;
      --dry-run) dry=1; shift;;
      -*) echo "teardown: unknown flag $1" >&2; return 2;;
      *) suffix="$1"; shift;;
    esac
  done
  [[ -n "$suffix" ]] || { echo "teardown: need a <suffix>" >&2; return 2; }
  case " $DENY_WS " in *" $suffix "*) echo "teardown: refusing denylisted $suffix" >&2; return 1;; esac
  [[ "$suffix" != "local/main" ]] || { echo "teardown: refusing local/main" >&2; return 1; }

  local root; root="$(list_workspaces | awk -F'\t' -v n="$suffix" '$1==n{print $2}')"

  run() { if (( dry )); then echo "DRYRUN: $*"; else "$@"; fi; }
  # Park FIRST so no unmerged work is lost.
  if [[ -n "$park" ]]; then run do_park "$suffix" "$park"; fi
  run del_bookmarks "$suffix"
  run del_remote    "$suffix"
  run forget_ws     "$suffix"
  [[ -n "$root" ]] && run rm_ws_dir "$root"
  run close_tab     "$suffix" "${root:-}"
}
```
> Implementer note: `run do_park …` under `--dry-run` prints the call rather than executing — acceptable, since park is destructive too. `del_bookmarks`/`forget_ws`/`del_remote` are internal functions; `run` calls them directly (they're tolerant of dry-run being off). This keeps a single code path.

- [ ] **Step 4: Run tests to verify they pass**

Run both; Expected: `ok: teardown_order`, `ok: dry_run`.

- [ ] **Step 5: Run the full suite**

Run: `bash test/jj-cleanup/run-all.sh`
Expected: all pass, `N passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add dot_local/bin/executable_jj-cleanup test/jj-cleanup/test_teardown_order.sh test/jj-cleanup/test_dry_run.sh
git commit -m "jj-cleanup: teardown command (ordered, --park, --dry-run)"
```

---

### Task 10: The `jj-pr-cleanup` skill (orchestration SOP)

**Files:**
- Create: `private_dot_claude/skills/jj-pr-cleanup/SKILL.md`

**Interfaces:**
- Consumes: `jj-cleanup scan --fetch`, `jj-cleanup teardown <suffix> [--park todo/<name>] [--dry-run]`.
- Produces: the skill Claude follows. No automated test (prose); verified by reading + a manual dry-run.

- [ ] **Step 1: Write `private_dot_claude/skills/jj-pr-cleanup/SKILL.md`**

```markdown
---
name: jj-pr-cleanup
description: Use when a lunar PR is closed/merged to master and you want to tear down its leftovers — local + remote bookmarks, the jj workspace, its directory, and its kitty tab — parking any unmerged work under todo/<name> first. Wraps the tested `jj-cleanup` tool; always confirms before mutating.
---

# jj-pr-cleanup

Tear down what a merged/closed PR leaves behind, safely. Backed by the tested
`jj-cleanup` tool (`~/.local/bin/jj-cleanup`). Model: `wip/<suffix>` on
`local/main` → mirror → `ijcd/<suffix>` PR branch → workspace `~/work/lunar/<suffix>`,
kitty tab `cc:<suffix>`. `local/main` and the `default`/`local-main` workspaces
are never touched.

## Steps

1. **Scan (read-only).** Run `jj-cleanup scan --fetch`. It fetches, then prints
   one row per workspace: `SUFFIX  PR  IJCD  LOST  TAB`.
   - `PR` = MERGED / CLOSED / OPEN / NONE / ERROR (from `gh`).
   - `LOST` = commits on `wip/<suffix>` beyond what the PR contained (unmerged
     tail), `+dirty` if the workspace has uncommitted changes.

2. **Pick.** Eligible = `PR` is **MERGED or CLOSED**. Never propose OPEN / NONE /
   ERROR rows. Present the candidates to the user as a short table.

3. **Name the parks.** For any candidate with `LOST > 0` (or `+dirty`), propose a
   descriptive `todo/<name>` (e.g. `todo/vault-hoist-retry`) — this is where the
   unmerged tail is preserved. Rows with `LOST 0` need no `--park`.

4. **Dry-run + confirm.** For each pick, run
   `jj-cleanup teardown <suffix> [--park todo/<name>] --dry-run` and show the exact
   commands. **Get explicit go/no-go from the user before mutating.**

5. **Execute.** On approval, run `jj-cleanup teardown <suffix> [--park todo/<name>]`
   per pick. Report what was deleted and where each park landed.

## Rules

- Confirm before any real teardown. Scan and `--dry-run` never mutate.
- One workspace per `teardown` call; loop over the user's picks.
- If a row is ERROR/NONE (gh failed, VPN down, no PR), **skip it and say why** —
  never guess-delete.
- `+dirty` means uncommitted work in the workspace `@`; always `--park` those.
- Parks land on `local/main`, resumable exactly like a `wip/*`.
```

- [ ] **Step 2: Verify the skill reads correctly**

Run: `cat private_dot_claude/skills/jj-pr-cleanup/SKILL.md` and confirm frontmatter (`name`, `description`) matches the sibling `jj-pr-workflow/SKILL.md` shape.

- [ ] **Step 3: Commit**

```bash
git add private_dot_claude/skills/jj-pr-cleanup/SKILL.md
git commit -m "jj-pr-cleanup: orchestration skill (scan → confirm → teardown)"
```

---

### Task 11: Deploy via chezmoi + smoke-test

**Files:**
- Modify: none (deployment only)

- [ ] **Step 1: Confirm chezmoi will place both artifacts**

Run: `chezmoi diff ~/.local/bin/jj-cleanup ~/.claude/skills/jj-pr-cleanup/SKILL.md`
Expected: shows the new executable (mode 0755) + the skill file. If the skill is NOT listed, the `.chezmoiignore` `!.claude/skills` negation didn't catch it — add `!.claude/skills/jj-pr-cleanup` and re-diff.

- [ ] **Step 2: Apply**

Run: `chezmoi apply ~/.local/bin/jj-cleanup ~/.claude/skills/jj-pr-cleanup/SKILL.md`
Expected: `~/.local/bin/jj-cleanup` is executable; skill present.

- [ ] **Step 3: Smoke-test scan against the live lunar repo (read-only)**

Run (in `~/work/lunar/<any workspace>` or the main repo): `jj-cleanup scan --fetch`
Expected: a table with real workspaces + PR states. **Read-only — safe.** Do NOT run `teardown` without a real merged branch + user confirm.

- [ ] **Step 4: Final full-suite run**

Run: `bash test/jj-cleanup/run-all.sh`
Expected: `N passed, 0 failed`.

- [ ] **Step 5: Commit any chezmoiignore tweak**

```bash
git add .chezmoiignore 2>/dev/null || true
git commit -m "jj-cleanup: track skill under .claude/skills" 2>/dev/null || echo "no chezmoiignore change needed"
```

---

## Self-Review

**Spec coverage:**
- Remove bookmarks → Task 7 (`del_bookmarks`) + Task 9 order. ✓
- Clean up remote branches → Task 8 (`del_remote`). ✓
- Move lost work to `todo/<name>` → Task 6 (`do_park`) + Task 9 park-first. ✓
- Forget workspace → Task 7 (`forget_ws`). ✓
- Clean up workspace dir → Task 7 (`rm_ws_dir`, guarded). ✓
- Close kitty tabs → Task 8 (`close_tab`). ✓
- Confirm before acting → Task 10 skill (dry-run + explicit go/no-go). ✓
- gh-for-status + revset-for-extras → Tasks 3 + 4. ✓
- Park onto `local/main` not `trunk()` → Task 6. ✓
- Denylist / rm guard / squash-safe / ijcd-only → Tasks 2, 7, 4; Global Constraints. ✓
- Scan-all-and-pick → Task 5 scan + Task 10 pick. ✓

**Placeholder scan:** No TBD/TODO; every code + test step has runnable content.

**Type/name consistency:** Helper names consistent across tasks — `resolve_base`, `list_workspaces`, `pr_state`, `prime_count`, `lost_tail_root`, `ws_dirty`, `do_park`, `del_bookmarks`, `forget_ws`, `rm_ws_dir`, `del_remote`, `close_tab`, `cmd_scan`, `cmd_teardown`. `__test_*` dispatch hooks match their helper. `DENY_WS`/`JJ_CLEANUP_WS_ROOT` used consistently.

**Known deviation (documented):** tests count the prime over `<base>..ijcd/<suffix>` rather than `trunk()..ijcd/<suffix>` for hermeticity (no `master@origin` in fixtures) — equivalent for counting the prime's own commits; noted in Task 4 and in a code comment.
