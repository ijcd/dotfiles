# Handoff: make `jjf` safe under concurrent workspaces (stop branch-deletion)

**Goal** — a well-behaved agent running a normal `jjf` command must never delete, cull, or
rewind *another workspace's* branches. Today it can, and did: five open PRs were closed when
one workspace's routine `jjf` reached across the shared op-log into another's branches.

Sibling to [`2026-09-01-jjf-push-prepush-hook.md`](2026-09-01-jjf-push-prepush-hook.md)
(compile-boundary gate) — same tool, same "jj bypasses git client hooks" constraint, different
failure. Coordinate: both touch the `jjf push` dispatch and `jjflow-lib.sh` helpers.

## Why this exists — the incident (2026-09-12)

Five PRs closed because their origin branches were deleted. Forensics from the shared op-log:

```
boundaries@  jj abandon 6ffb9c1f   → ijcd/test-quin-knowledge-coverage   (#4617)
boundaries@  jj abandon 4213abba   → ijcd/test-quin-fhir-coverage        (#4619)
boundaries@  jj abandon 270a460f   → ijcd/test-quin-event-payloads-…     (#4620)
boundaries@  jj abandon 74225c8b   → ijcd/fix-gql-queries-rcm-byid       (#4588)
boundaries@  jj abandon f760fb53   → ijcd/fix-gql-queries-encounters     (#4612)
   …interleaved with "point bookmark ijcd/fix-dangling-app-exception" + "duplicate 1 commit"
later:  jj git push --deleted      → propagated all local deletions to origin → PRs closed
```

**The two-part vector (this is the whole bug):**

1. A **repo-wide `jjf` op** (mirror/catchup — both run the orphan cull) abandoned bookmarks
   that had *no `wip/*` source thread*. The five were standalone `ijcd/*` (created directly,
   not mirrored from `wip/*`), so the cull classified them as orphans and `jj abandon`ed them
   **locally**. jjflow-mirror.sh cull: **`jjflow-mirror.sh:1326-1352`** (delete+abandon at
   1349-1352; a partial ownership guard already exists at :1345 but did not save cross-workspace
   branches).
2. **`jj git push --deleted`** (raw jj, run manually — NOT via jjf; jjf itself correctly
   avoids it, see `jjflow-cleanup.sh:124`) then pushed **every** local bookmark deletion to
   origin, including the other workspace's. `--deleted` ignores `-t`/scoping entirely. **This
   is the step that crossed to GitHub and closed the PRs.**

Root truth: `jjf` operations are **repo-global**, but an agent only *owns* its own workspace's
threads. Nothing confines a command to its lane.

## The five changes (priority order)

### #3 first — it's the keystone. Guard the remote *delete* step.
`--deleted` is what actually closes PRs, and it bypasses everything else. Two parts:

- **jjf side:** any `jjf` path that could push a deletion must abort on a `[delete from …]`
  preview unless `JJF_ALLOW_DELETE=1`. Wire into the push dispatch (`jj-flow:177` →
  `jjflow-mirror.sh:1635 push_main`), same slot the prepush-gate plan uses.
- **raw-jj side (REQUIRED — the incident was raw jj):** a `jj` wrapper shim earlier in `PATH`
  that intercepts `jj git push … --deleted` (and any `jj git push` whose plan deletes a remote
  branch) and **refuses** unless `JJ_ALLOW_DELETE=1`. A git `pre-push` hook will NOT work —
  jj writes refs directly and never fires git client hooks (same reason the prepush-hook plan
  exists). The wrapper is the only reliable interception point.
  - ⚠️ **Invasive — flag for human review before deploy.** A global `jj` shim sits in front of
    *every* jj call in every session; a bug there breaks all jj usage. Keep it minimal: pass
    through untouched except the specific dangerous argv shapes; overridable by env.

### #4 — Guard history rewinds on a shared op-log.
Same `jj` wrapper: intercept `jj undo` and `jj op restore`. In a repo whose op-log head has
advanced since this session's last op (i.e. a peer wrote it), **refuse** unless
`JJ_ALLOW_REWIND=1` — these revert *other* sessions' operations. (Seen in the op-log earlier
the same day: `restore to operation …` / `abandon` from concurrent sessions.)

### #1 — Scope `jjf` to the caller's ownership set by default.
`jjf mirror` / `catchup` currently cull repo-wide unless `-t/--thread` is passed. Flip it:
- With no `-t` and no explicit `--repo-wide`, **either** derive the current workspace's threads
  (the `wip/*` stacked on this workspace's base `local/main-<W>`) and scope to them, **or**
  refuse with "pass `-t wip/<name>` or `--repo-wide`". Refusing is the simpler fail-safe.
- Anchor: cull is gated by the `wanted` union in `jjflow-mirror.sh:1278-1352`; ownership/base
  derivation already exists via `flow_load_config` / `FLOW_BASE` (see the prepush plan).

### #2 — The orphan cull may only delete bookmarks in the ownership set.
Harden `jjflow-mirror.sh:1326-1352`: before `jj bookmark delete`/`jj abandon` on a prime, prove
its source thread belongs to **this** workspace's base. If ownership can't be determined,
**do not cull** (fail safe — the opposite of today, where an undetermined orphan gets culled).
This makes a cross-workspace delete structurally impossible even if #1 is bypassed.

### #5 — Advisory lock around mutating `jjf` verbs.
Wrap the mutating verbs (push/mirror/catchup/cleanup) in an `flock` on a per-repo lockfile
(e.g. `"$(jj root)/.jj/.jjf-lock"`), so two workspaces can't interleave bookmark mutations +
push and produce a reconcile that drops a bookmark. Reads (`status`, `guide`) take no lock.
Add a timeout + clear "another jjf op is running" message.

## Acceptance / test
- `jjf mirror` with no `-t` from workspace A does **not** touch workspace B's `ijcd/*` (or
  refuses). Add a fixture with two workspaces + a standalone `ijcd/*` in B; assert B survives.
- `jj git push --deleted` refuses without `JJ_ALLOW_DELETE=1`; a normal scoped push still works.
- `jj undo` refuses when the op-log head moved since last local op; works when it didn't, or with
  `JJ_ALLOW_REWIND=1`.
- Two concurrent `jjf push` serialize (second waits/reports), don't interleave.
- Every override env documented in `jjf guide`.

## Caveats for the implementing (chezmoi) agent
- Files are chezmoi-managed (`dot_local/bin/`, `jjf` is `symlink_jjf`). Edit **source**, then
  `chezmoi apply`. Currently on branch `ijcd/jj-mirror-detect-stuck`.
- **Live-shared:** all sessions source these files; a deploy changes behavior for everyone
  mid-flight. Land guards fail-safe + override-able so a false positive is recoverable, and
  announce before `chezmoi apply`.
- Residual gap #1/#2/#3 can't fix: the GitHub branch **namespace** is shared — two workspaces
  can still both target `ijcd/foo`. Consider per-workspace prefixes (`ijcd/<W>/…`) as a
  follow-up; out of scope here.
- Unrelated but found during this incident: the GitHub token is stored **plaintext** in jj
  config (`jj-vine.github.token`, readable via `jj config list`). Move to keyring/env.
