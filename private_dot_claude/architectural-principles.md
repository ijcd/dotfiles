# Architectural Principles

Dense reference. Each principle stands alone — grep to a section and apply it without reading the whole doc.

---

## Functional Core, Imperative Shell

**Rule:** Pure logic lives in domain modules; side effects live in event handlers, workers, controllers, and mix tasks.

**Why:** Logic in shell only fires on one access path. Logic in the core fires on every path — admin tools, API, seeds, future features — without being re-implemented. Shell code that reimplements business rules creates divergent behavior and untestable code.

**How to apply:** Ask "does this function do any IO?" If yes, it belongs in the shell (LiveView event handler, Oban worker, controller, task). If no, it belongs in the core (domain module, resource helper, calculation module). The shell composes core functions — it does not reimplement them. View formatting lives in components and helpers. Data invariants go on resources (Ash validations, identities, change modules), not on LiveView or controllers.

A LiveView `handle_event/3` body should be a thin composition layer: call one (or a small set of) domain functions, then assign results or navigate. If a `handle_event` body contains validation logic, persistence orchestration, or multi-step business rules beyond a single Ash action call, that logic belongs in a domain module. The tell: if you'd have to duplicate the logic in a controller, a worker, OR an admin action — it's in the wrong place.

**Anti-pattern:** Writing the same validation in a controller AND on the resource. Writing a price formatter inside a LiveView event handler. Doing a DB query inside a `display_price/1` function. A `handle_event` body that validates params, calls multiple Ash actions conditionally, and then derives a result — none of which is reachable from a background job or API endpoint.

---

## Elm Model / Command-over-Data Thinking

**Rule:** Express domain operations as explicit named commands over immutable data; build reducers that apply them; invert every command for reversibility.

**Why:** Ad-hoc mutation scattered across handlers makes behavior impossible to trace, test, or reverse. When each operation is a command with a defined inverse, round-trip correctness is provable and undo is cheap.

**How to apply:** For any group of related operations on a domain entity, identify the command set and its inverses. Example from variant pricing: `add_variant/promote`, `adopt/promote`, `parentify/promote_both`. Each command has a name, preconditions, and an inverse. Implement them as functions in the domain module. Shell code calls commands; it does not directly mutate state.

When designing a new feature, write the command table first:

| Command | Inverse | Effect |
|---|---|---|
| `add_variant(parent, label, price)` | `promote(variant)` | Creates variant; migrates price+guid on first variant |
| `adopt(parent, existing_item)` | `promote(variant)` | Sets parent_item_id |
| `parentify(item_a, item_b)` | `promote(a)`, `promote(b)` | Creates new parent; both become children |

**Anti-pattern:** Updating `parent_item_id` directly in a LiveView event without naming the operation. Writing state transitions as raw `update_item` calls without a domain command layer.

---

## Property Tests for Invariants and Round-Trips

**Rule:** Use property-based testing (`StreamData`/`ExUnitProperties` in Elixir; language equivalent elsewhere) to verify invariants that must hold across any command sequence, AND for any pure function that accepts multiple input shapes.

**Why:** Unit tests cover specific inputs. Property tests find the edge cases you didn't think to write. For systems with commands and inverses, the only way to prove round-trip correctness is to generate arbitrary command sequences and assert the invariants hold. For pure functions with polymorphic inputs (different shapes, sizes, or value ranges), example tests miss the boundary; generators don't.

**How to apply:** Two triggers for property tests:

1. **Pure functions with multiple input shapes** — any function that pattern-matches on different map shapes, list lengths, integer ranges, or string content needs property tests: symmetry (commutative operations), round-trip (encode → decode == identity), bounds (output stays within valid range for any valid input). Use `StreamData.member_of/1`, `StreamData.map/2`, `gen all` to build generators that match the actual domain.

2. **Command sets (see Elm Model principle)** — write property tests that:
   - **Round-trip:** `apply(inverse(command(state))) == state` (set-equivalent, not necessarily byte-equivalent — new UUIDs differ)
   - **Invariants under sequence:** pick 3-5 domain invariants that must hold after any command, then generate random command sequences and assert them

Example invariants for variant pricing:
- Total item count minus orphan count is stable under forward/backward operations
- Each item's `toast_guid` is preserved across structural moves
- `display_price/1` for any view is deterministic from current state
- Cascade `:source` for any item is invariant under structural moves

For cascade/resolver logic, test all non-empty subsets of N layers (2^N - 1 cases for N=3 is 7 — finite, exhaustive).

**Anti-pattern:** Writing only example-based tests for domain logic that composes. Trusting that "add then remove" is correct without generating sequences that test it. Writing a single `assert normalize("$10.00") == 1000` when the function must handle `"10"`, `"10.0"`, `"$10"`, `"$10.00"`, `10.0` — write a property that every valid representation normalizes to the same canonical value.

---

## TypeCheck / Runtime-Spec'd Public APIs

**Rule:** Annotate cross-module public APIs with `@spec!` (TypeCheck) or the language's equivalent runtime-checked spec; enable only in dev/test; disable in prod. Standard `@spec` (dialyzer-only) is insufficient for functions whose inputs are polymorphic or caller-supplied maps.

**Why:** Elixir's `@spec` is doc-only (dialyzer analyzes it statically but it doesn't catch runtime shape violations). TypeCheck's `@spec!` raises at runtime when argument shapes violate the spec — catches subtle shape bugs at the boundary during development before they propagate deep. This matters most at module boundaries: a function that only one caller ever uses can rely on convention; a function called from multiple contexts (domain module, LiveView, worker, admin task) cannot.

**How to apply:** On pure function modules (the functional core), annotate ALL public functions with `@spec!`. This is not optional for cross-module public APIs — standard `@spec` is insufficient for polymorphic-input functions. Complex inputs that are maps or structs should be fully typed. On the cascade resolver example: `@spec! merge_layers([layer]) :: layer` and `@spec! resolve(Menu.Item.t()) :: %{values: map, sources: map, derived_tags: [String.t()]}`. Enable TypeCheck's runtime checking in `dev` and `test` mix environments; disable in `prod` (TypeCheck generates compile-time wrappers so prod has zero overhead).

The test: if two different modules call a function and you can't tell from the spec whether both callers pass compatible shapes — you need `@spec!`.

In other languages: use the equivalent (TypeScript strict mode, Python runtime type checkers like `beartype`, Go struct validation on public API boundaries).

**Anti-pattern:** Leaving complex inter-module data flows unspec'd because "we know the shapes." Using bare `@spec` for polymorphic-input functions and calling it done. Enabling runtime checking in prod (this is wrong — use it as a dev-time probe only).

---

## TDD: Write Failing Test First, Always

**Rule:** Write a failing test before any implementation. No exceptions. Prove correctness — never infer it.

**Why:** The failure mode isn't inefficiency — it's shipping bugs that seem obviously correct. Tests written after implementation tend to confirm the code that exists, not the behavior required. Tests written first force you to specify the contract before coding it. Real incident: repeated production deploys that failed to hide a seasonal menu because the date logic was "obviously correct" but wasn't.

**How to apply:**
1. Write failing test describing expected behavior.
2. Run it — verify it fails for the RIGHT reason (not a compilation error, not a fixture problem).
3. Write the minimum code to make it pass.
4. Refactor while green.

For bugs: write a regression test FIRST (prove the bug exists), then fix. The test turns green; the bug can never return undetected.

Priority order: **Correct and working → Refactor → Fast.** Never "quickest fix." Understand the root cause; prove it with a test; then fix.

For exploratory feasibility spikes: use a throwaway branch or `iex`. When work returns to the real branch, it is test-first from that point.

**Anti-pattern:** Implementing an entire feature then writing tests as a "sanity check." Writing tests that only pass because they mirror the buggy code. Deploying "it should be fine" without `mix test` showing 0 failures.

---

## Normalize Before Comparing

**Rule:** Convert values to a canonical form before any equality check or diff across layers or sources.

**Why:** The same logical value can have different representations: `"$10.00"` vs `10.0` vs `1000` (cents) vs `"10"`. Comparing across sources without normalization produces false positives (values differ only in representation) and false negatives (equivalent values missed by a fuzzy match). This breaks staleness detection, change diffing, and any system that must answer "are these the same?"

**How to apply:** Define a canonical type for each domain value (e.g., `price_cents :: integer`). Write a `to_canonical/1` function. Always call it before comparing. For price: everything normalizes to cents (integer). For names: lowercase + strip extra whitespace + unicode normalization. The cascade resolver runs stale-override detection as `override.value != cascade.value` — this only works if both sides were normalized when stored.

Build normalization into the ingestion boundary (when Toast data enters the system, normalize immediately). Normalization at comparison time is a smell — it means you're doing it repeatedly at the wrong layer.

**Anti-pattern:** Storing `price_display` as a raw string and doing fuzzy pattern matches on it to determine if values differ. Comparing `"$10.00"` to `"10.0"` and concluding they're different.

---

## Parameterize All Helpers in Shared Components

**Rule:** When a shared component calls a helper function, every field name and context the helper depends on must be passed as an argument — never hardcoded.

**Why:** A component that calls `format_price(item)` looks reusable but secretly depends on the field `:price_cents`. When that component is used for a different item type with `:cost_cents`, the helper silently returns wrong data. This is a hidden bug class that only surfaces at runtime with specific item types.

**How to apply:** Audit every helper called inside a shared component. If the helper references a field by name (via pattern match, `Map.get`, `item.field`), that field name must be a parameter. If the helper has different behavior based on context, that context must be a parameter. The component is field-agnostic in its body and field-specific only at the call site.

Periodic DRY refactor pass: during a code review cycle, scan all shared components (component library, storybook entries) for helpers that embed field names or context assumptions.

**Anti-pattern:** `format_price(item)` that hardcodes `item.price_cents` inside a shared menu item row component. `render_badge(item)` that assumes `:toast_guid` is the binding field.

---

## Ports and Adapters (Hexagonal Architecture)

**Rule:** Domain logic does not import from the web layer, the persistence layer, or any external service directly. Those dependencies flow inward via adapters; the domain defines the interface.

**Why:** Domain code that imports `Ecto.Repo` or `Phoenix.LiveView` is untestable in isolation and couples business rules to framework details. When the framework changes (or you add a new access path), you rework business logic. When domain logic is pure functions that take plain data, tests run without a database, a web server, or an external service.

**How to apply:** In Elixir/Ash: business rules live in `lib/liberties/` domain modules. The web layer (`lib/liberties_www_web/`) calls domain functions. Persistence is mediated by Ash resources (the adapter). Domain modules do NOT import `Ecto.Repo`, `Phoenix.Component`, or external HTTP clients. Workers and controllers are adapters — they translate between the domain and infrastructure.

The test for this: if you can run all tests for `Liberties.Menu.Resolver` with no database, no web server, no external network — you have it right.

**Anti-pattern:** A `Liberties.Menu` function that imports `LibertiesWeb.Router.Helpers` to build a URL. A domain resource that calls `HTTPoison.get!/1` directly instead of through an adapter boundary.

---

## Reference Models Are Read-Only; Local Models Are Admin-Owned

**Rule:** External system pulls (POS data, scrapers, SFTP imports) write ONLY to reference models (e.g., `toast_*`). Local rendering models are admin-owned and never auto-modified by sync.

**Why:** Auto-overwriting local data destroys admin work silently. Names, descriptions, and prices on the website can intentionally differ from the POS (curated copy, marketing positioning, fewer items). If a sync overwrites the local model, an admin's carefully crafted description is silently replaced with a POS-side copy that may be a SKU code or a bare item name.

**How to apply:** Sync workers write to `toast_menu_items`, `toast_online_menu_items`, etc. — the reference tables. The bridge between reference and local is explicit admin action only (a mapping/diff tool where the admin reviews divergences and chooses what to propagate). The cascade resolver reads both sides but NEVER writes to the local model based on what it reads. Binding (connecting a local item to a Toast GUID) is admin-set; the GUID is the join key for reading, not for overwriting.

For any new external integration: ask "does this sync touch a `Liberties.Menu.*` or `Liberties.Accounts.*` resource?" If yes, redesign to use a reference model instead.

**Anti-pattern:** A Toast SFTP import worker that calls `Ash.update!(menu_item, %{price_cents: toast_price})`. A scrape job that updates `menu_item.description` when the Toast description changes.

---

## Explicit Data over Implicit String Parsing

**Rule:** Model domain values as typed data (integers, enums, structs, variant records); eliminate string fields that carry multiple unrelated concerns.

**Why:** Strings that encode multiple concerns (`price_display = "$10/$14"` carries numeric price AND variant structure AND market-price annotation) break sorting, normalization, comparison, and cascade logic. They force downstream code to parse rather than consume. Each parser is a potential inconsistency and a test burden.

**How to apply:** When a string field is doing double or triple duty, replace it with typed fields. For price: `price_cents :: integer`, `price_note :: string`, and variant structure (child items) replace a `price_display` string. For tagged values: use tagged tuples `{:ok, value}` / `{:error, reason}` / `{:override, value}` instead of sentinel strings. Prefer flat `case` on shape over nested if/else on string values.

Migration path: make the old field nullable; add new typed fields; write a migration function that converts old strings to typed data; update all readers; drop the old field. Never skip the "update all readers" step — leaving stale read paths means the old string keeps getting read.

**Anti-pattern:** `price_display = "MP"` as a magic string checked with `== "MP"`. A status field stored as `"active"/"inactive"` when an atom/enum would do. A `attrs` JSON blob used as a poor-man's type system for fields that should be first-class columns.

---

## CSS via Semantic Classes — Never Inline Tailwind

**Rule:** Never write Tailwind utilities directly in templates. Extract to semantic CSS classes with `@apply`. One `@apply` per line with an aligned comment.

**Why:** Inline utilities scatter presentation logic across every template, make it impossible to find "where is the button style defined?", and break global updates (changing a color requires grep across all templates). Semantic class names communicate intent; utility strings communicate only implementation.

**How to apply:** Create a CSS class named after the component's role (`app-hero-tagline`, `admin-section-header`). Use `@apply` one directive per line with a comment. Group classes under a section comment. Responsive variants MUST come last (CSS output order matters with nested media queries). DaisyUI component classes (`input`, `btn`, `table`, etc.) cannot use `@apply` — keep those inline.

This rule applies to ALL templates — public, admin, and internal LiveViews alike. Admin LiveViews are not exempt. The only exception is DaisyUI primitives (`btn`, `input`, `badge`, `table`, `card`, etc.) which must stay inline. Any Tailwind utility in an admin template that is not a DaisyUI primitive belongs in a semantic class.

```css
.app-price-display {
  @apply font-mono;              /* monospaced digits */
  @apply text-sm;                /* smaller than body */
  @apply text-neutral-600;       /* subdued */
  @apply tabular-nums;           /* aligned decimals */
  @apply md:text-base;           /* responsive — MUST BE LAST */
}
```

**Anti-pattern:** `<p class="font-mono text-sm text-neutral-600 tabular-nums md:text-base">$12</p>` directly in a template. Extracting a class named `big-text` or `blue-button` that describes implementation rather than purpose. Treating admin LiveView templates as exempt from this rule because "admin pages don't matter."

---

## UX: Suggestions Not Auto-Set; Defaults Match Current Behavior

**Rule:** When the system can infer a value, offer it as a suggestion the user accepts — never set it automatically. Default values must match the current rendered behavior, not an opinionated new behavior.

**Why:** Auto-setting a value that the user didn't choose is a hidden change. If the system auto-sets a name to a Toast-derived value and the admin had a reason for their current name, their work is silently overwritten. Changing defaults also changes current behavior for existing records — every record that was relying on the previous default now behaves differently without the admin doing anything.

**How to apply:** For any form field where the system can suggest a value (match suggestion, import from external source, calculated default): pre-populate the field with the suggestion but require an explicit save action. Surface suggestions as "badges" or "chips" the admin clicks to accept. For defaults: if an existing item renders a certain way today, the default setting must preserve that rendering (Tufte: don't make me think). Use click-to-edit patterns consistently — the same interaction for overriding any field, everywhere in the admin.

Example: when a variant is added to an existing single-priced item, the variant's name defaults to the existing item's name (preserving current rendered behavior) — not to a blank field.

**Anti-pattern:** A sync worker that applies a "better" name from Toast without prompting the admin. A form that changes a default value, causing existing records to render differently after a deploy.

---

## Deploys Are Code-Only; Data Changes Are Explicit

**Rule:** Deploys contain only code changes. Data changes (seeding, migrations of existing values, POS syncs) are separate deliberate actions with preview-and-confirm.

**Why:** Coupling data changes to deploys creates accidental data mutation. An auto-seed on deploy can overwrite admin edits. Auto-migrations that run silently on startup can corrupt data when the migration logic has a bug. Preview-and-confirm surfaces what will change before it happens.

**How to apply:** `release_command` in `rel/config.exs` (or equivalent) runs schema migrations only — never data seeding, never value migrations. Seeding is a separate mix task (`mix menu.push`, `Release.seed/0`) invoked out-of-band with explicit human intent. Value migrations (e.g., converting `price_display` strings to typed fields) run as a one-time mix task with a dry-run mode that shows diffs before applying.

**Anti-pattern:** Auto-running `Liberties.Release.seed()` as part of the deploy `release_command`. A migration that silently rewrites field values without a dry-run preview.

---

## Fail at Runtime, Not at Deploy

**Rule:** Non-critical integration secrets should surface errors at runtime (dashboards, health checks), not block deploys by raising at boot.

**Why:** A failed deploy blocks ALL code changes — not just the one that needs the missing secret. A runtime error on the dashboard exposes the missing secret without blocking the pipeline. Core secrets (database URL, signing keys) can still be required at boot; those failures are not recoverable at runtime.

**How to apply:** Separate secrets into two tiers. Tier 1 (required at boot): `DATABASE_URL`, `SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET` — if missing, the app cannot function at all. Tier 2 (required for a feature): `TELNYX_API_KEY`, `SLACK_BOT_TOKEN`, POS integration keys — if missing, that feature is disabled; the rest of the app runs fine. Use `System.get_env/1` with conditional config for Tier 2. Surface Tier 2 failures as dashboard warnings, not boot crashes.

**Anti-pattern:** `Env.require!("SLACK_BOT_TOKEN")` at application startup, blocking every deploy until the secret is set even though Slack notifications are not on the critical path.

---

## Storybook for Visual Component Testing

**Rule:** Extract UI components to a component library (Phoenix Storybook or equivalent); mount at a dev-only route; write closed-form component tests at the component level before integrating.

**Why:** Integration-level visual testing is brittle and slow. Storybook-style component-level tests isolate the component from its data source, letting you verify rendering variants (empty, loaded, error, edge cases) in isolation. Component regressions are caught at the component test level before they appear in full-page tests.

**How to apply:** When building a new shared component: define it in the component library first. Write storybook entries for each rendering variant (default, empty state, loading, edge case inputs). Mount the storybook at `/_dev/storybook` (dev-only). Write LiveView component tests that render the component with controlled props and assert on the rendered output. Integrate into pages only after the component tests are green.

**Anti-pattern:** Building a component inline in a LiveView template and only discovering rendering edge cases when the full page test runs with unexpected data.

---

## Ash: Batch Over Loop; Atomic Change Modules

**Rule:** In Ash apps, use `Ash.bulk_update/4` (or `Ash.bulk_create/3`) instead of `Enum.each` + single-record Ash calls. Extract change modules with an `atomic/3` callback for any change that may run inside a bulk operation.

**Why:** An `Enum.each` loop over Ash update calls is N+1 database round-trips. `Ash.bulk_update` applies the action to all matching records using the minimal number of queries, while still running all hooks and business rules (unlike raw SQL). Without an `atomic/3` implementation on a change module, that change is silently skipped or raises during bulk operations in Ash 3.x.

**How to apply:**

```elixir
# Instead of:
items |> Enum.each(fn item ->
  item |> Ash.Changeset.for_update(:mark_inactive, %{}) |> Ash.update!(authorize?: false)
end)

# Use:
import Ash.Expr
MyApp.Items.Item
|> Ash.Query.filter(status == :pending and inserted_at < ^cutoff)
|> Ash.bulk_update(:mark_inactive, %{}, authorize?: false)
```

For change modules used in any action that may be called via `bulk_update`, implement `atomic/3`:

```elixir
defmodule MyApp.Changes.SetProcessed do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.change_attribute(changeset, :processed, true)
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end
end
```

The pattern extends to query-side: `Ash.bulk_create/3` for seeding/importing batches, `Ash.Query.filter` to scope bulk operations by business rules (not raw SQL `WHERE`).

**Anti-pattern:** `Enum.each` over a list loaded with `Ash.read!` applying per-record updates. A change module that only implements `change/3` but is used in bulk actions — it silently becomes a no-op or raises in Ash 3.x bulk paths.

---

## Multi-Source Collections Need a Unified View Module

**Rule:** When data lives in multiple tables/sources but represents one
conceptual entity, create a single module that exposes the unified view.
Source-specific queries are for sync/import layers only.

**Why:** Ad-hoc merging at every consumer leads to two bug classes:
(a) bugs of omission — one consumer forgets a source, items become
invisible in that consumer's view; (b) bugs of inconsistency — merge
logic drifts between consumers, items show differently depending on
where you look.

**How to apply:** When designing a new query/list/pool, ask "is this
collection naturally multi-source?" If yes, build (or extend) the
unified module. Consumers go through the module, never to the
underlying tables. Variable names matter: `current_toast` invites
confusion; `toast_items` or `all_toast_items` invite correctness.

**Anti-pattern:** Variable names that imply "the current subset" of a
conceptually-unified collection (e.g., `current_toast` when there are
also SFTP and report sources). They train future readers to grab the
nearest list without thinking about completeness.

**Implementation choice — view-in-code vs view-as-dbview:**
- View-in-code (function module that merges in Elixir) — simplest, fits
  pure-function discipline, easy to property-test. Default choice.
- View-as-dbview (Postgres VIEW backed by AshPostgres view resource) —
  earns its weight when AshAdmin/AshAi need to browse the unified
  collection, or when merge becomes a measurable hot path. The interface
  is identical, so migration is internal.
