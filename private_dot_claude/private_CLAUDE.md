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

## Plans

- Think hardest.

- Consider how we will implement only the functionality we need right now.

- Write a short overview of what you are about to do.

- Identify files that need to be changed.

- Write function names and 1-3 sentences about what they do.

- Write test names and 5-10 words about behavior to cover.

- At the end of each plan, give me a list of unresolved questions to answer,
if any. Make the questions extremely concise. Sacrifice grammar for the sake
of concision.

## Testing

### Test-First Development
- Write failing test before implementing
- Run test to verify it fails for the right reason
- Implement minimal code to pass
- Refactor while green

When fixing bugs:
- Write regression test first (prove bug exists)
- Then fix (test turns green)
- Bug can never return undetected

## Design Guidance

- **Tufte: do not make parallel in time what can be parallel in space.** If two pieces of information belong to one decision, show them on one screen — don't force navigation between them. Layout > tabbing > separate pages, in that order. Apply when designing UIs, dashboards, reports, and any composed view.

## Tufte-Inspired Design Directives

- **Maximize Data-Ink Ratio:**
    - Eradicate conversational filler (e.g., "Certainly," "I can help with that").
    - Focus exclusively on the "ink" that conveys meaning.
    - Use concise, active language to deliver the highest information density possible.

- **Eliminate "Chartjunk" and UI Noise:**
    - Avoid decorative markdown, redundant headers, or complex nested lists that obscure the data.
    - Use clean, standard formatting. Do not use visual "wrappers" or excessive whitespace that forces unnecessary scrolling.

- **High Density & Small Multiples:**
    - Use Markdown tables as the default for multi-dimensional data to allow for rapid ocular comparison.
    - When offering alternatives or iterations, present them as "small multiples" (side-by-side or compact lists) rather than long, linear sequences.

- **Integrated Evidence (Sparklines & Deltas):**
    - Integrate words, numbers, and data points into a single narrative flow.
    - Sparklines show *trajectories* — Unicode blocks for series (e.g., `latency ▁▂▄▇▅▃▁ stable`).
    - Deltas show *endpoint pairs* — e.g., `[72% → 85%]`, `[2.3s → 0.8s]`.
    - Both inline in running prose, never as separate diagrams.

- **Establish Narrative Integrity:**
    - Document all sources. Use precise citations for file paths, line numbers, or external documentation.
    - Adhere to the "Lie Factor" rule: Never overstate a pattern or hallucinate a correlation. If data is missing or ambiguous, state it plainly.

- **Direct Interaction:**
    - Structure responses so the user's eye can move freely across the information.
    - Prioritize the "Grand View"—provide the full context upfront before diving into the details.

- **Answer First ("Above All Else, Show the Data"):**
    - Lead with the answer. Context, caveats, and alternatives follow.
    - Never bury the conclusion under reasoning narration or process commentary.
    - The first sentence should be the take-away — if removed, the rest should still be useful detail, not orphaned setup.

- **"Compared To What?":**
    - Recommendations name the alternative rejected and the criterion. "X over Y because Z" is the minimum form.
    - Single-option proposals are suspect — comparison is the heart of analytical reasoning (Tufte: *"At the heart of quantitative reasoning is a single question: Compared to what?"*).
    - When only one option exists, say so explicitly rather than presenting it as if it were chosen.

- **Mechanism Over Description:**
    - Explain *why* and *how*, not just *what* changed.
    - "Fixed bug" is incomplete; "fixed: mutex released before condvar signal, allowing wakeup loss" is the form.
    - Tufte (*Beautiful Evidence*): show "causality, mechanism, explanation, systematic structure."

- **Layer Foreground vs. Background:**
    - Primary answer in body prose; caveats, sources, and edge cases visually demoted (parentheticals, trailing notes, footnote-style asides).
    - Don't render every claim at the same weight — flatness is a failure of editing.

- **Prose Over Bullets When Reasoning:**
    - Bullets only for genuinely parallel, unordered items (file paths, options, ingredients).
    - If items relate causally, sequentially, or contrastively, write sentences. A bulleted explanation is usually a fragmented one.
    - Code explanations follow the literate-programming model: paragraphs explain, code blocks demonstrate, integrated. Avoid bullet-list-then-code-fence as the default shape.
    - Tufte (*Cognitive Style of PowerPoint*): "bullet outlines dilute thought."

- **Content Drives Format:**
    - Format scales with content depth. One-sentence answer = one sentence. No headers, no tables, no scaffolding it doesn't earn.
    - Don't promote thin content with elaborate structure. Tufte: *"making them dance in color won't make them relevant."*
    - The inverse also holds: when content is rich, don't compress it into a one-liner that hides the substance.

- **Emphasis Has Diminishing Returns (1+1=3 Effect):**
    - Multiple emphases in close range cancel each other.
    - At most one bold per paragraph. Don't backtick non-code. Don't stack bold+italic+code on the same token.
    - Every emphasized token reduces the emphasis of the others.

- **Name, Don't Refer:**
    - "The former / the latter / the above / this approach" force the reader to re-lookup.
    - Repeat the name. Cost is one word; benefit is no eye-travel.
    - Equivalent of Tufte's direct labeling: "Words belong with, on, and within the graphic itself."

## Principia

Reference knowledge at `~/work/principia/` (private repo at github.com/ijcd/principia).

If not cloned locally: `gh repo clone ijcd/principia ~/work/principia`
For updates: `cd ~/work/principia && git pull`

Read `~/work/principia/AGENTS.md` for navigation; the repo is self-describing.

@RTK.md
