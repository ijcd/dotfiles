# macOS Config Capture / Apply / Merge Toolkit — Design

**Status**: Proposed (2026-06-25)

## Context

The repo already has two config layers:

- **chezmoi** — text dotfiles. Capture = `chezmoi add`, apply = `chezmoi apply`, merge = git/`chezmoi merge`.
- **nix-darwin / Home Manager** — packages + *curated* macOS defaults hand-written in `settings.nix` (Dock, Finder, Terminal profile, tiling keys).

Neither covers a third class of state: settings you **tune live inside an app** (Rectangle layouts, Alfred, assorted app prefs) and **opaque app state** (Hazel `.hazelrules`). These are plist- or blob-backed, can't be hand-authored in nix (nix can't express plist `<data>` — NSColor etc.), and don't sync on their own.

Goal: a repeatable way to **capture** that state into the repo (reviewed), **apply** it back to a machine (deliberately), and **merge** divergence reasonably.

## Goals / Non-goals

**Goals**
- Bidirectional flow, but inbound changes are **reviewed** before landing (git diff is the review surface).
- **Tiered with honest guarantees** — text-ifiable config gets real diff/merge; opaque blobs get tracked copies, no false promises.
- **Disjoint ownership** with nix — the toolkit and `settings.nix` never write the same keys.
- Fits existing conventions (`dot_local/bin/` scripts, built-in tools only).

**Non-goals**
- No auto-apply on `chezmoi apply` or `darwin-rebuild switch` (would clobber live local tweaks).
- No 3-way merge of binary blobs (impossible; last-writer + loud warning instead).
- Not a replacement for an app's own sync (e.g. Hazel Rule Sync remains an option).
- No auto-generation of `settings.nix`.

## Model

**Source-of-truth: bidirectional, review-gated on inbound.** Any machine can change settings locally. `capture` pulls them into the repo working tree; you review via `git diff` / `git add -p` and commit what you approve. `apply` pushes committed state to a machine and is always **explicit** — never silent, so it can't overwrite a local tweak you haven't captured.

**Tiers**

| Tier | What | Storage | Diff/merge |
|------|------|---------|------------|
| 1 | `defaults` domains (Rectangle, Alfred, app prefs) | XML plist (`plutil -convert xml1`) | full git diff + 3-way merge |
| 2 | opaque app files (Hazel `.hazelrules`, App Support blobs) | byte copy | changed/unchanged only; merge = last-writer (warned), or defer to app sync |

## Components

All scripts live in `dot_local/bin/` (chezmoi-deployed to `~/.local/bin`), depend only on `defaults`, `plutil`, `git`, `rsync`/`cp` — all macOS-native.

1. **Manifest** — `macos-config/manifest.conf` in the repo. Line-based (no TOML parser dep):
   ```
   # tier      identifier                                  options
   defaults    com.knollsoft.Rectangle                     restart=Rectangle
   defaults    com.runningwithcrayons.Alfred-Preferences
   file        Library/Application Support/Hazel           restart=Hazel match=*.hazelrules
   exclude     com.apple.dock                              # owned by settings.nix
   exclude     com.apple.finder
   exclude     NSGlobalDomain:EnableTilingByEdgeDrag
   ```
   - `defaults <domain> [restart=<proc>]` — Tier 1.
   - `file <path-under-$HOME> [restart=<proc>] [match=<glob>]` — Tier 2.
   - `exclude <domain[:key]>` — owned by nix; capture refuses/warns.

2. **`macos-config-capture [item…]`** — for each Tier-1 item: `defaults export <domain> - | plutil -convert xml1 -o macos-config/defaults/<domain>.plist -`. For Tier-2: copy matching files into `macos-config/files/<domain-or-slug>/`. Refuses/warns on any `exclude` domain or key. Leaves changes in the working tree for review (does **not** auto-commit).

3. **`macos-config-apply [item…]`** — explicit. Tier-1: `plutil -convert binary1` to a temp + `defaults import <domain> <file>`, then `killall cfprefsd` to flush the cache and run each `restart=` hook. Tier-2: copy files back (requires `--force` or interactive confirm, since it overwrites). Supports `--dry-run`.

4. **`macos-config-diff [item…]`** — preview machine-vs-repo without writing: live `defaults export` piped through `plutil -convert xml1`, diffed against the stored plist. Pre-capture sanity check.

5. **`macos-config-list`** — the inventory/overview. A table over the manifest: item, tier, captured? (✓/✗), last captured (from `git log -1` on the stored file), restart hook, excluded?. Footer summary: counts of captured vs declared-but-uncaptured, excluded, and **orphans** (files in `macos-config/` with no manifest entry, or manifest entries with no captured data). This is the "what do I have, and is anything stale/missing" view. Flags: `--captured`, `--missing`, `--orphans` to filter.

6. **`macos-config-show <item>`** — view one captured config, human-readable. Tier-1: `plutil -p` pretty-print of the stored plist (key count in the header). Tier-2: file listing with sizes + a clear "binary blob — not renderable" note. Read-only, never touches the machine.

## Storage layout

```
macos-config/                       # repo-only (added to .chezmoiignore)
  manifest.conf
  defaults/
    com.knollsoft.Rectangle.plist   # XML — diffable, mergeable
    com.runningwithcrayons.Alfred-Preferences.plist
  files/
    Hazel/<watched-folder>.hazelrules   # binary — tracked, not diffable
```

Captured data is **repo-only** (chezmoi-ignored): it is *source*, not something to deploy into `~` — the apply path is `defaults import`, not file placement. Scripts locate the repo via `chezmoi source-path` (fallback `~/.local/share/chezmoi`).

## Coordination with nix (the ownership boundary)

Two systems can write macOS defaults; they must not overlap.

- **nix `settings.nix`** owns settings you *decide once* (system UX, curated keys). Listed as `exclude` entries in the manifest.
- **The toolkit** owns settings you *tune live and capture back*.
- `capture` checks every domain/key against the `exclude` set and **skips + warns** rather than pulling a nix-owned value into the repo. Keeps the two layers from fighting (`darwin-rebuild` reasserting vs a captured tweak) and keeps capture output clean.

The exclude list is maintained by hand in the manifest, documented to track `settings.nix`. (Auto-deriving from nix eval was considered and rejected as fragile — see Alternatives.)

## Error handling

- `capture`: missing domain → warn + skip. Excluded domain/key → refuse + warn.
- `apply`: validate plist parses (`plutil -lint`) before import; `killall cfprefsd` after import so changes take effect; run restart hooks; non-zero on any failed import. `--dry-run` prints planned actions only.
- Tier-2 apply overwrites → gated behind `--force`/confirm; absolute-path caveat documented (rules/blobs may embed machine-specific paths).

## Testing

- **Roundtrip**: `capture` then `apply` on the same machine → `diff` reports no change.
- **Dry-run**: `apply --dry-run` lists actions, touches nothing.
- **Exclude guard**: capturing an excluded domain warns and writes nothing.
- **Inventory**: `list` marks a freshly-captured item ✓, an uncaptured manifest entry ✗, and reports a stray file in `macos-config/` as an orphan; `show` pretty-prints a Tier-1 plist and labels a Tier-2 blob as binary.
- `shellcheck` clean.

## Alternatives considered

- **chezmoi `run_onchange` hooks (auto-apply)** — rejected: fires on every `chezmoi apply`, pushing repo→machine constantly, which fights the bidirectional "don't clobber my local tweak" intent.
- **Auto-generate `settings.nix` from capture** — rejected: nix can't express plist `<data>`; only covers trivial key types; not reviewable as the app sees it.
- **Auto-derive the exclude list from nix eval** — rejected for v1 as fragile; a hand-maintained list is explicit and good enough.
- **Home Manager `writeShellApplication` packaging** — rejected: deps are all macOS-native, so pinning buys nothing, and rebuild-per-edit is friction. Plain `dot_local/bin/` matches the existing ~70 scripts.

## Consequences

- A new repo-only `macos-config/` tree (chezmoi-ignored) + the `macos-config-*` scripts in `dot_local/bin/` (`capture`, `apply`, `diff`, `list`, `show`).
- One new discipline: when you add a declarative key to `settings.nix`, add a matching `exclude` line to the manifest.
- Tier-2 (Hazel etc.) is tracked but explicitly *not* safely mergeable across diverged machines — for live two-machine sync of those, the app's own mechanism is still the better tool.
