# jj-mirror merge-based resync — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline) or
> superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Stop jj-mirror force-pushing live PRs — once a prime bookmark backs an
open PR, advance it only to a descendant (merge-forward) instead of rewriting.

**Architecture:** Per-member mode selection in `sync_thread`. A member whose dest
bookmark has an open PR is advanced via `advance_merge` (two-parent merge:
first-parent = new base, second-parent = old tip, tree hard-set to freshly
derived content). All others keep today's clean cherry-pick. Keep-condition is
generalized to be first-parent-aware, unifying both modes.

**Tech Stack:** Bash 4+, jj 0.43.0, `gh` (live detection, injectable via
`JJ_MIRROR_LIVE_PRS`), plain-bash test harness under `test/jj-mirror/`.

## Global Constraints

- File: `dot_local/bin/executable_jj-mirror` (chezmoi → `~/.local/bin/jj-mirror`).
- Bash 4+; `set -euo pipefail`; `shasum` not `sha256sum`; no jq/python/node.
- Diff hashing MUST force `--git` (both `diff_hash` and `range_diff_hash` already do).
- Read first-parent order-preserving: `parents.map(|p| p.commit_id().short()).join("\n") | head -n1`. Never the `-` operator (unordered).
- Live path: forward-only bookmark moves, NO `--allow-backwards`; assert old tip ∈ ancestors(new) before moving.
- Tests: `bash test/jj-mirror/run-all.sh` all green; no network — live set injected via `JJ_MIRROR_LIVE_PRS`.
- Commit only when the user asks.

---

### Task 1: `live_pr_set` — injectable live-PR detection

**Files:**
- Modify: `dot_local/bin/executable_jj-mirror` (new function near `load_config`)
- Test: `test/jj-mirror/test_live_pr_set.sh`

**Interfaces:**
- Produces: `live_pr_set()` → prints one live dest-bookmark name per line.
  Memoized per process via `_LIVE_PR_SET` cache. Resolution: `JJ_MIRROR_LIVE_PRS`
  (space-separated) → `gh pr list --state open --json headRefName -q '.[].headRefName'`
  → remote-tracking-ref fallback + one-time warning.
- Consumes: nothing.

- [ ] **Step 1: failing test** — env override returns exactly the injected set; empty when unset and gh absent.

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
out=$(JJ_MIRROR_LIVE_PRS="pr/a pr/b" "$SCRIPT" _live-pr-set)
assert_eq $'pr/a\npr/b' "$out" "env-injected live set"
# gh-absent, no remote, no env → empty (PATH stripped of gh)
out=$(PATH=/usr/bin JJ_MIRROR_LIVE_PRS="" "$SCRIPT" _live-pr-set 2>/dev/null || true)
assert_eq "" "$out" "empty when no signal"
cd / && rm -rf "$repo"; echo "ok: live_pr_set"
```

- [ ] **Step 2: run, verify FAIL** — `bash test/jj-mirror/test_live_pr_set.sh` (unknown subcommand `_live-pr-set`).
- [ ] **Step 3: implement** `live_pr_set()` + a hidden `_live-pr-set` dispatch case (alongside `_dump-config`).

```bash
_LIVE_PR_SET=""; _LIVE_PR_SET_DONE=0
live_pr_set() {
  (( _LIVE_PR_SET_DONE )) && { printf '%s' "$_LIVE_PR_SET"; return 0; }
  local out=""
  if [[ -n "${JJ_MIRROR_LIVE_PRS+x}" ]]; then
    out=$(printf '%s\n' $JJ_MIRROR_LIVE_PRS | awk 'NF')
  elif command -v gh >/dev/null 2>&1; then
    out=$(gh pr list --state open --json headRefName -q '.[].headRefName' 2>/dev/null | awk 'NF' || true)
  else
    # fallback: dest bookmarks with a remote-tracking ref
    out=$(jj bookmark list -T 'if(remote, name ++ "\n", "")' 2>/dev/null | awk 'NF' | sort -u || true)
    [[ -n "$out" ]] && echo "jj-mirror: gh not found — treating pushed bookmarks as live (merge mode)" >&2
  fi
  _LIVE_PR_SET="$out"; _LIVE_PR_SET_DONE=1
  printf '%s' "$_LIVE_PR_SET"
}
# helper: is DEST live?
dest_is_live() { local d=$1; live_pr_set | grep -qxF "$d"; }
```

- [ ] **Step 4: run, verify PASS.**
- [ ] **Step 5: commit** (only if user asks) — `feat(jj-mirror): live_pr_set with JJ_MIRROR_LIVE_PRS injection + gh + remote fallback`.

---

### Task 2: `advance_merge` — the merge-forward mechanic in isolation

**Files:**
- Modify: `dot_local/bin/executable_jj-mirror` (new function before `sync_thread`)
- Test: `test/jj-mirror/test_advance_merge.sh`

**Interfaces:**
- Produces: `advance_merge SCID PREV E DEST` — builds `D=duplicate SCID -d PREV`,
  `F=jj new PREV E`, `restore --from D --into F`, `abandon D`, asserts
  `E ∈ ancestors(F)`, sets `DEST -r F` forward-only. Prints new commit id `F`.
  Returns 2 on conflict or broken invariant.
- Consumes: nothing from other tasks.

- [ ] **Step 1: failing test** — single member, base advances; assert F is a 2-parent merge, parent[0]==new base, E is ancestor (ff), tree==derived, bookmark moved.

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
printf 'base\n' > f; jj commit -m M0 >/dev/null; jj bookmark set master -r @- >/dev/null
# prime tip E = A on master (diff: +a)
jj new master >/dev/null; printf 'base\na\n' > f; jj commit -m A >/dev/null
E=$(jj log --no-graph -r @- -T 'commit_id.short()'); jj bookmark set pr/a -r "$E" >/dev/null
# master advances to M1 (adds unrelated file)
jj new master >/dev/null; printf 'base\n' > f; printf 'x\n' > other
jj commit -m M1 >/dev/null; jj bookmark set --allow-backwards master -r @- >/dev/null
M1=$(jj log --no-graph -r master -T 'commit_id.short()')
# source SCID: same +a content, authored on M1 (simulate wip rebased)
jj new master >/dev/null; printf 'base\na\n' > f; jj commit -m S >/dev/null
S=$(jj log --no-graph -r @- -T 'commit_id.short()')
F=$("$SCRIPT" _advance-merge "$S" "$M1" "$E" pr/a)
# 2 parents, first == M1
parents=$(jj log --no-graph -r "$F" -T 'parents.map(|p| p.commit_id().short()).join("\n")')
assert_eq "$M1" "$(printf '%s\n' "$parents" | head -n1)" "first parent = new base"
[[ $(printf '%s\n' "$parents" | wc -l) -eq 2 ]] || fail "F not a 2-parent merge"
# E is ancestor of F (fast-forward)
jj log --no-graph -r "$E & ancestors($F)" -T '"y"' | grep -q y || fail "E not ancestor of F"
# tree: f has +a, other present (from M1)
jj file list -r "$F" | grep -qx other || fail "M1 content missing from F"
[[ "$(jj file show -r "$F" f)" == $'base\na' ]] || fail "derived content wrong"
# bookmark moved to F
assert_eq "$F" "$(jj log --no-graph -r pr/a -T 'commit_id.short()')" "pr/a -> F"
cd / && rm -rf "$repo"; echo "ok: advance_merge"
```

- [ ] **Step 2: run, verify FAIL** (`_advance-merge` unknown).
- [ ] **Step 3: implement** `advance_merge` + `_advance-merge` dispatch.

```bash
advance_merge() {
  local scid=$1 prev=$2 e=$3 dest=$4 out d f cflag
  out=$(jj duplicate "$scid" --destination "$prev" 2>&1)
  d=$(printf '%s\n' "$out" | awk '/^Duplicated/{print $5; exit}')
  [[ -n "$d" ]] || { echo "jj-mirror: advance_merge duplicate failed for $scid" >&2; return 1; }
  jj new "$prev" "$e" -m "jj-mirror: merge-forward $dest" >/dev/null 2>&1 \
    || { echo "jj-mirror: advance_merge new-merge failed ($prev,$e)" >&2; return 1; }
  f=$(jj log --no-graph -r @ -T 'commit_id.short()')
  jj restore --from "$d" --into "$f" >/dev/null 2>&1 \
    || { echo "jj-mirror: advance_merge restore failed" >&2; return 1; }
  jj abandon "$d" >/dev/null 2>&1 || true
  # append-only invariant: old tip must be an ancestor of the new commit
  if ! jj log --no-graph -r "$e & ancestors($f)" -T '"y"' 2>/dev/null | grep -q y; then
    echo "jj-mirror: append-only violation — $e not an ancestor of $f for $dest" >&2; return 2
  fi
  cflag=$(jj log --no-graph -r "$f" -T 'if(conflict,"y","n")' 2>/dev/null)
  [[ "$cflag" == y ]] && { echo "jj-mirror: conflict merge-forwarding $dest ($f)" >&2; return 2; }
  jj bookmark set "$dest" -r "$f" >/dev/null 2>&1 \
    || { echo "jj-mirror: advance_merge bookmark set failed for $dest" >&2; return 1; }
  printf '%s' "$f"
}
```

- [ ] **Step 4: run, verify PASS.**
- [ ] **Step 5: commit** (if asked).

---

### Task 3: wire per-member mode into `sync_thread`

**Files:**
- Modify: `dot_local/bin/executable_jj-mirror:733-812` (`sync_thread`)
- Test: `test/jj-mirror/test_merge_basebump.sh`, `test/jj-mirror/test_merge_edit_cascade.sh`, `test/jj-mirror/test_merge_notlive_regression.sh`

**Interfaces:**
- Consumes: `live_pr_set`/`dest_is_live` (Task 1), `advance_merge` (Task 2).
- Produces: no new external interface; behavior change only.

Keep-condition generalized (replace `:776-790` block):
- `fp = jj log -r existing -T 'parents.map(|p| p.commit_id().short()).join("\n")' | head -n1`
- `e_hash = range_diff_hash(fp, existing)`; `s_hash = diff_hash(scid)`
- keep iff `fp == prev && e_hash == s_hash`.

Rebuild branch (replace `:793-810`): if `dest_is_live "$(dest_for leaf-or-bm)"`
and `existing` non-empty → `new_cid=$(advance_merge scid prev existing dest)`;
else the existing `jj duplicate … -d prev` clean build. Then `set_dest_bookmarks`
for any *additional* bookmarks (leaf dest already set by advance_merge).

- [ ] **Step 1: failing test — base bump, single live PR merge-forwards (ff, no sideways).**

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
repo="$(mkrepo)"; cd "$repo"
# master M0; wip/a on local base; sync creates pr/a
printf 'base\n' > f; jj commit -m M0 >/dev/null; jj bookmark set master -r @- >/dev/null
jj new master >/dev/null; printf 'base\n' > f && jj commit -m localbase >/dev/null
jj bookmark set local/main -r @- >/dev/null
jj new local/main >/dev/null; printf 'base\na\n' > f && jj commit -m a >/dev/null
jj bookmark set wip/a -r @- >/dev/null; jj new @- >/dev/null
"$SCRIPT" sync >/dev/null
A0=$(jj log --no-graph -r pr/a -T 'commit_id.short()')
# master advances; source unchanged content, mark pr/a live
jj new master >/dev/null; printf 'base\n' > f; printf 'x\n' > other
jj commit -m M1 >/dev/null; jj bookmark set --allow-backwards master -r @- >/dev/null
JJ_MIRROR_LIVE_PRS="pr/a" "$SCRIPT" sync >/dev/null
A1=$(jj log --no-graph -r pr/a -T 'commit_id.short()')
[[ "$A0" != "$A1" ]] || fail "pr/a did not advance on base bump"
# append-only: A0 is an ancestor of A1 (fast-forward, no force-push)
jj log --no-graph -r "$A0 & ancestors($A1)" -T '"y"' | grep -q y \
  || fail "pr/a moved sideways — NOT a fast-forward"
cd / && rm -rf "$repo"; echo "ok: merge_basebump"
```

- [ ] **Step 2: run, verify FAIL** (today: A0 is not ancestor of A1 — rebuilt sideways).
- [ ] **Step 3: implement** the keep-condition + rebuild-branch changes in `sync_thread`.
- [ ] **Step 4: run, verify PASS.**
- [ ] **Step 5: failing test — mid-stack edit, live stack, each downstream PR gets one appended ff merge.** (build 3-member live stack; edit middle source; assert pr/mid and pr/top advance and each old tip is ancestor of new; pr/bottom unchanged.)
- [ ] **Step 6: implement/adjust if needed; verify PASS.**
- [ ] **Step 7: regression test — non-live member still cherry-picks sideways** (no `JJ_MIRROR_LIVE_PRS`; assert old tip is NOT ancestor of new after a base bump — proves clean path intact). Verify PASS.
- [ ] **Step 8: run full suite** `bash test/jj-mirror/run-all.sh` — existing `test_sync_*` green. Commit (if asked).

---

### Task 4: `thread_verdicts` lockstep + `merge-forward` verdict

**Files:**
- Modify: `dot_local/bin/executable_jj-mirror:868-938` (`thread_verdicts`), `:1014-1034` (`dry_run_thread`)
- Test: `test/jj-mirror/test_merge_dryrun.sh`

**Interfaces:**
- Consumes: `dest_is_live` (Task 1).
- Produces: `thread_verdicts` emits action `merge-forward` where sync would merge.
  `verdict_state` maps `merge-forward` → `stale` (a live member that needs a merge
  is not yet ok). `dry_run_thread` prints "would merge-forward <dest>".

- [ ] **Step 1: failing test** — after a base bump with `JJ_MIRROR_LIVE_PRS=pr/a`, `sync --dry-run` output contains `would merge-forward pr/a`; a non-live sibling shows `would rebuild`.
- [ ] **Step 2: run, verify FAIL.**
- [ ] **Step 3: implement** — mirror the generalized keep-condition (first-parent + `range_diff_hash`) into `thread_verdicts`; when action would be `diff`/`cascade` AND `dest_is_live`, emit `merge-forward`. Add the `dry_run_thread` case and `verdict_state` mapping.
- [ ] **Step 4: run, verify PASS.**
- [ ] **Step 5: commit** (if asked).

**Lockstep note:** the keep-condition in `thread_verdicts` and `sync_thread` MUST
match byte-for-byte (`:782`). Both use `first_parent` + `range_diff_hash(fp, existing)`.

---

### Task 5: squash-mode merge-forward + regression + docs

**Files:**
- Modify: `dot_local/bin/executable_jj-mirror:818-858` (`squash_thread`), `:876-889` (squash verdict), header/help note
- Test: `test/jj-mirror/test_merge_squash.sh`

**Interfaces:**
- Consumes: `advance_merge`, `dest_is_live`.
- Produces: single-PR squash threads merge-forward when their dest is live.

- [ ] **Step 1: failing test** — squash rule, dest live, base bump → dest advances and old tip is ancestor of new (ff).
- [ ] **Step 2: run, verify FAIL.**
- [ ] **Step 3: implement** — in `squash_thread`, when `existing` non-empty and `dest_is_live "$dleaf"`, route through `advance_merge` with `SCID` = the folded cumulative commit (build the fold onto `prime_root` first, then merge-forward its tip). Keep the no-op path.
- [ ] **Step 4: run, verify PASS.**
- [ ] **Step 5: full regression** `bash test/jj-mirror/run-all.sh` all green. Update the tool banner/help to mention merge mode; cross-reference this spec. Commit (if asked).

---

## As-built deltas (discovered during TDD)

Three things the plan didn't anticipate, fixed in-flight:

1. **`jj restore` rewrites the commit id.** `advance_merge` must track the merge
   by CHANGE id and re-resolve the commit id AFTER restore — using the pre-restore
   id left the bookmark on the auto-merge tree (old content from the 2nd parent),
   silently dropping edits. (`merge_forward_to`)
2. **Existing-chain enumeration must follow the first-parent spine.** `proot..dleaf`
   drags a merge-forward's 2nd parent (old tip) into the range, corrupting the
   positional walk. New `prime_chain` walks first-parents, stopping at the first
   ancestor-of-proot. Routed both `sync_thread` and `thread_verdicts` through it.
3. **Memoization was defeated by `$()`.** `live_dest_for` via command-substitution
   forked the resolver, so `gh` ran once per stale member. `sync_thread` now checks
   `dest_is_live` inline (main process) — verified 1 gh call per sync, 0 on no-op.

Also: `advance_merge` split into `merge_forward_to` (merge+restore+assert+bookmark,
reused by squash) + the single-commit duplicate wrapper. Squash merge-forward needs
a real prime root — root-commit-as-prime-root can't be a merge parent (degenerate;
can't occur with a live PR).

## Self-review

- **Spec coverage:** §Merge-forward mechanic → Task 2; §keep-condition → Tasks 3,4;
  §Live detection → Task 1; §Blast radius rows → Tasks 3 (sync_thread, set_dest_bookmarks),
  4 (thread_verdicts, dry-run), 5 (squash_thread); §Testing scenarios → Tasks 1-5 tests.
- **Placeholder scan:** Steps 5-7 of Task 3 and Task 5 describe test intent without
  full code — expand to concrete scripts at execution time (same shape as the fully
  written tests above; the primitives are proven).
- **Type consistency:** `advance_merge SCID PREV E DEST` signature identical across
  Tasks 2,3,5. `live_pr_set`/`dest_is_live` identical across Tasks 1,3,4,5.
  `first_parent` read + `range_diff_hash(fp, existing)` identical in Tasks 3,4.
