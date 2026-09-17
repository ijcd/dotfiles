# Handoff: `jjf push` should run a repo pre-push gate

**Goal** — close the one hole in lunar's boundary enforcement: `jj` bypasses client-side
git hooks, so `jjf push` ships boundary violations to CI that `git push` would have caught
locally. Make `jjf push` run the repo's pre-push check and abort on failure.

## Why this exists

lunar now gates boundary warnings at four layers (PR #4397):

| Layer | Mechanism | Who it catches |
|---|---|---|
| compile | `mix compile` — boundary stays **advisory** | nobody (by design; refactors not blocked) |
| on-demand | `mix check` alias | whoever runs it |
| pre-push (git) | `.githooks/pre-push` → `mix compile --warnings-as-errors` | `git push` users |
| CI | `mix compile --warnings-as-errors` in `lunarci.yml` | everyone, non-bypassable |

The pre-push layer is a **git** hook (`core.hooksPath=.githooks`, wired by `mix setup`).
`jj` never invokes git client hooks — `jj git push` / `jj-vine submit` write refs directly.
So jj users (all lunar agents) skip straight from advisory-compile to CI. First they hear of
a boundary break is a red CI run. That's the gap.

## Where the hook slots in

`jjf push` dispatch, exact path:

- `jj-flow:177` — `push)` arm: `_flow_mod mirror; … flow_load_config; … mirror_main push "$@"`
- `jjflow-mirror.sh:1635` — `push_main()`: `sync_main` (re-derive `ijcd/*` from `wip/*`),
  then `exec jj-vine submit --tracked` (the actual remote write)

Insert the gate in the **dispatcher** (`jj-flow:177`), after `flow_load_config` and before
`mirror_main push`. Keeps it out of the 76KB mirror internals, and `flow_load_config` has
already run so `_cfg` is available.

```sh
push)  shift; _flow_mod mirror
       jj root >/dev/null 2>&1 && { flow_load_config; export JJ_MIRROR_SOURCE_ROOT="$FLOW_BASE"; }
       flow_run_prepush_gate || exit $?          # <-- new
       mirror_main push "$@"; exit $? ;;
```

## Mechanism — two options, recommend B

### B (recommended): honor the repo's existing pre-push hook

Reuse `.githooks/pre-push`. jj users get the **identical** gate git users get — no second
copy of the check to drift. Generic: any repo with a pre-push hook benefits; repos without
one are unaffected.

Helper in `jjflow-lib.sh` (alongside `flow_load_config`, ~:43):

```sh
# Run the repo's pre-push gate before jjf pushes. Honors core.hooksPath (jj's git
# hooks are otherwise never fired). No hook / not executable => no-op, exit 0.
flow_run_prepush_gate() {
  local hooks_dir hook
  hooks_dir=$(_cfg prepush-hooks-path "$(git -C "$(jj root)" config core.hooksPath 2>/dev/null)")
  hooks_dir=${hooks_dir:-.githooks}
  hook="$(jj root)/$hooks_dir/pre-push"
  [[ -x "$hook" ]] || return 0
  printf 'jjf: running %s (git hooks are skipped by jj)…\n' "$hooks_dir/pre-push" >&2
  ( cd "$(jj root)" && "$hook" </dev/null )   # </dev/null: hook must not block on ref stdin
}
```

Config key `jj-flow.prepush-hooks-path` overrides the path; default resolves
`core.hooksPath` then falls back to `.githooks`. Bypass = env flag (below).

### A (escape hatch): a config'd command

If a repo wants a gate but no hook file:

```sh
FLOW_PREPUSH_CMD=$(_cfg prepush-cmd '')      # add to flow_load_config
# in flow_run_prepush_gate, before the hook-file path:
[[ -n "$FLOW_PREPUSH_CMD" ]] && { eval "$FLOW_PREPUSH_CMD" </dev/null; return $?; }
```

Set per-clone: `jj config set --repo jj-flow.prepush-cmd 'mix compile --warnings-as-errors'`.

## Caveats — read before implementing

- **git-hook stdin contract.** A real git pre-push hook gets `<remote> <url>` as argv and
  the pushed refs on **stdin**. Running it standalone gives neither. lunar's hook ignores
  both (it just runs `mix format` + `mix compile`), so `</dev/null` is safe. A hook that
  parses stdin refs would misbehave — B is only correct for check-style hooks. Document the
  assumption; don't try to synthesize the ref list.
- **Per-repo jj config isn't shared.** `jj config set --repo` writes `.jj/repo/config.toml`
  (local, per-clone, not tracked) — every clone/workspace re-sets it. Option B avoids this
  by keying off a **tracked** file (`.githooks/pre-push`), so it ships with the repo. Prefer B
  for that reason alone.
- **Bypass.** Mirror git's `--no-verify`: honor `JJF_NO_VERIFY=1` (skip the gate, print that
  CI still enforces). Agents mid-refactor need an escape that doesn't fight the tool.
- **Cost.** `mix compile --warnings-as-errors` on a warm `_build` is cheap (incremental);
  cold (fresh workspace) it's the full compile tax. `jjf push` already does network work, so
  the marginal wait is usually fine — but a cold per-workspace `_build` will sting. If that
  bites, gate on `_cfg prepush-hooks-path` being explicitly set rather than defaulting on.

## What's NOT in this handoff

- No edit applied to `jjf` — this is the design only. Implementation is the 8-line dispatcher
  + helper above, in chezmoi source `dot_local/bin/`.
- lunar-side wiring assumes B (nothing to set — `.githooks/pre-push` already carries the
  boundary check as of #4397). Option A would need the per-clone `jj config set --repo`.
- No test harness for jjf. Manual check: touch a boundary violation on a `wip/*`, `jjf push`,
  confirm it aborts; `JJF_NO_VERIFY=1 jjf push` confirms bypass.
