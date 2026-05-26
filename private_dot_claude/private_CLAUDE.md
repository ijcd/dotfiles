## Cardinal Rule

- When I ask a question, ANSWER IT. Do not take action. Never create, edit,
  or delete files in response to a question. Never run mutating commands in
  response to a question. Only act when I give an explicit instruction to do
  so. This is non-negotiable.

- In all interactions and commit messages, be extremely concise and sacrifice grammar for the sake of concision.

## Subagents

- Always use subagents when the task fits one. Never ask "subagent or
  inline?" — pick a subagent and go. Inline only when no subagent fits.

- Don't halt for two-way-door decisions. Small choices with low blast
  radius (UX details, naming, ordering, defaults, confirm/no-confirm,
  copy strings): decide, present as "here's what we did, easy to
  change", continue. Idle time on small questions is the cost.

- Either/or execution = parallel subagents, always. If the decision is
  genuinely "approach A vs approach B" and both produce real work,
  dispatch BOTH as parallel subagents and let me pick from the
  outputs. Don't ask which one; run both.

- Independent work = parallel subagents in ONE message. Anytime
  multiple subagent tasks have no dependency between them, dispatch
  them as concurrent Agent calls in a single message. If you write
  "in parallel", the next message must contain N Agent calls.
  Verify the count before sending. Sequential dispatch of
  independent work wastes wall time and creates phantom in-flight
  status. Skip what you can — when in doubt, parallelize.

- Reserve real questions for one-way doors: irreversible actions
  (deploy, force-push, schema migrations, deleting branches), or
  decisions whose blast radius can't be quickly undone.

## Architecture: Functional Core, Imperative Shell

- Pure logic (cascade resolution, normalization, formatting, business
  rules) lives in domain modules / resource helpers. No IO, no side
  effects, fully testable in isolation. This is the functional core.

- Side effects (DB writes, scrape calls, message sends, file writes)
  live in event handlers, workers, controllers, mix tasks. Thin layer:
  compose pure functions, don't reimplement them. This is the
  imperative shell.

- Data invariants belong at the resource/model level (Ash validations,
  identities, calculations, change modules). Don't duplicate them in
  LiveView event handlers or controllers — invariants you write in the
  shell only fire on one access path; invariants on the resource fire
  on every path (admin tools, API, seeds, future features).

- View formatting lives in components and helpers. When a shared
  component calls a helper, parameterize EVERY field/context that
  helper depends on. Hardcoding a field name in a helper called from
  a multi-instance component is a hidden bug class — the component
  is field-agnostic in body but field-specific in internals.

- Prefer flat case statements over nested if/else/with for branching
  logic. Tagged tuples (e.g. `{:override, value}`, `{:online, value}`)
  let case-on-shape replace conditional cascades.

- Normalize to a canonical form before comparing values across layers
  or sources. "Are these equal?" is a question whose answer differs by
  representation; "Are their canonical forms equal?" doesn't.

## Visual Companion

- In brainstorming, default-on. Never ask for consent — start the server and
  push the first visual on the first visual question.

## PR Comments

<pr-comment-rule>
When I say to add acomment to a PR with a TODO on it, use
'checkbox' markdown format to add the TODO. For instance:

<example>
- [ ] A description of the todo goes here
</example>
</pr-comment-rule>
- When tagging Claude in the GitHub issues, use '@claude'

## Changesets

To add a changeset, write a new file to the `.changeset` directory.

The file should be named `0000-your-change.md`. Decide yourself whether to
make it a patch, minor, or major change.

The format of the file should be:

```md
---
"evalite": patch
---

Description of the change.
```

The description of the change should be user-facing, describing which features
were added or bugs were fixed.

## GitHub

- Your primary method for interacting with GitHub should be the GitHub CLI.

## PR Forks (upstream contributions)

When forking a repo to submit a PR:

1. **Local location**: Clone to `~/work/prs/<repo-name>`
2. **Branch naming**: Use `ijcd/<description>` prefix (e.g., `ijcd/fix-endpoint-url`)
3. **Topic tag**: Add `pr-fork` topic for easy discovery
   ```bash
   gh repo fork <owner>/<repo> --clone=false
   gh repo edit ijcd/<repo> --add-topic pr-fork
   git clone git@github.com:ijcd/<repo> ~/work/prs/<repo>
   cd ~/work/prs/<repo>
   git checkout -b ijcd/fix-something
   ```
3. **Cleanup**: After PR merged, delete local and archive/delete fork
   ```bash
   rm -rf ~/work/prs/<repo>
   gh repo delete ijcd/<repo> --yes
   # or archive instead: gh repo archive ijcd/<repo>
   ```
4. **Find all PR forks**: `gh repo list ijcd --topic pr-fork`

## Git

- When creating branches, prefix them with ijcd/ to indicate they come from me.
- Do not add "Generated with Claude Code" or Co-Authored-By lines to commit messages.
- After each commit, show the commit message and --stat output inline in the response (not just as tool output). 

## Principia

Reference knowledge at `~/work/principia/` (private repo at github.com/ijcd/principia).

If not cloned locally: `gh repo clone ijcd/principia ~/work/principia`
For updates: `cd ~/work/principia && git pull`

When you need a specific area:
- **Planning a non-trivial change** → `~/work/principia/practices/planning.md` (overview, files, function names, test names, unresolved questions)
- **Writing prose** (responses, commit messages, PR descriptions, docs) → `~/work/principia/practices/writing-style.md` (Tufte directives)
- **Working with coding agents** → `~/work/principia/practices/agents.md` (modes, scope discipline, tooling tier)
- **TDD / testing philosophy** → `~/work/principia/architectural-principles.md#tdd-write-failing-test-first-always`
- **Engineering ethos** → `~/work/principia/ETHOS.md`
- **Language style** → `~/work/principia/languages/<lang>.md`

Read `~/work/principia/AGENTS.md` for the full router.

Read `~/work/principia/AGENTS.md` for navigation; the repo is self-describing.

@RTK.md
