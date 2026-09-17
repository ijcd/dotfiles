# QUEUED — jjf push / jj-vine: emit progress so agents can tell hung from working

**Requested:** 2026-09-16, alongside the kitty-tab color work. Queue behind the
jjf-catchup-targeted-scope build (and the kitty-tab work).

## Problem

`jjf push` goes silent for the whole GitHub round-trip. An agent watching the process
(`ps` + tail the task output file) sees **live process, zero output** — indistinguishable
from hung. "No output is not good for agents": they can't answer "is it hung or working?"

Observed: agent reported "still running, 2 jjf/jj-vine procs, no output yet" for minutes —
which was the *only* honest thing it could say, because nothing is emitted.

## Root cause (`dot_local/bin/jjflow-mirror.sh:1721-1737`)

```sh
push_main() {
  sync_main                         # local jj surgery — fast, prints
  exec jj-vine submit --tracked     # process REPLACED; jj-vine silent until PR URL
}
```

1. `exec` replaces jjf with jj-vine (done so jj-vine's exit code becomes jjf's). Cost:
   jjf can no longer wrap/tee/heartbeat the slow phase.
2. jj-vine (external, https://codeberg.org/abrenneke/jj-vine) buffers through its
   `git push` + GitHub API calls and only prints the PR URL at the end.

Result: the slow, network-bound phase produces no bytes → hung and working look identical.

## Fix menu

**(a) Cheap 80% — pass `-v` + a phase marker (probably enough).**
jj-vine HAS `-v/--verbose` (confirmed via `jj-vine submit --help`) — `push_main:1725`
just doesn't pass it. So:
- `exec jj-vine submit --tracked -v` → jj-vine streams what it's doing; "working" now
  produces output, only a true hang stays silent.
- Print a boundary line before the handoff, e.g.
  `echo "jj-mirror: sync ✓ — handing to jj-vine (GitHub push + PR round-trip)…" >&2`
  so the agent knows which phase the silence (if any) belongs to.
- Consider gating `-v` behind an env/flag (e.g. `JJF_PUSH_VERBOSE=1`) if always-verbose
  is too noisy for humans — but default-on is better for the agent use case.

**(b) Robust — heartbeat wrapper (stop `exec`-ing).**
Run jj-vine as a CHILD, not exec: `jj-vine submit --tracked -v & pid=$!`, tee its output,
and on an interval emit `jj-mirror: jj-vine still running (${n}s elapsed)…`; `wait $pid`
and forward its exit code so the clean-exit-code property `exec` gave us is preserved.
This makes even a genuinely-silent jj-vine observably alive, and lets us add a timeout /
"looks stuck after Ns" nudge.

Recommend shipping (a) first; add (b) if silent stretches still bite.

## Related / prior art

- Current branch `ijcd/jj-mirror-detect-stuck` already ships *stuck-STATE* detection
  (`test/jj-mirror/test_status_stuck.sh`, `test_sync_stuck.sh`) — a branch that can't
  sync. This is a DIFFERENT axis: runtime *process* liveness during push. Note the
  overlap when building.
- `plans/2026-09-13-jj-vine-shim-DISABLED.sh` — a PATH shim around jj-vine (for token
  hygiene, disabled). Shows the shim pattern if we want to intercept jj-vine's invocation.
- `plans/2026-09-01-jjf-push-prepush-hook.md`, `plans/2026-09-12-jj-flow-safety-hardening.md`
  — adjacent push/safety work.

## Note

`ideas/` is chezmoi-ignored (tracked in git, not deployed). After the fix, changes to
`dot_local/bin/**` need `chezmoi apply` to reach `~/.local/bin`.
