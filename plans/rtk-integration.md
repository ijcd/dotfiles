# RTK integration

Add [rtk](https://github.com/rtk-ai/rtk) (Rust Token Killer) to dotfiles, declaratively. Compresses Claude Code's Bash-tool output 60-90%. Affects only Claude Code, not interactive shell.

## Decisions (locked)

- **A**: capture-after-init. Run `rtk init -g`, copy what it produces into chezmoi source.
- **Drift detection**: rely on `homebrew.upgrade = false` (RTK won't move silently); add `private_dot_claude/.rtk-version` marker for visibility.
- **Telemetry**: off (`rtk telemetry disable` after install).
- **Config**: capture `~/.config/rtk/config.toml` if RTK creates one.
- **Defaults** for everything else.

## Files

### Phase 1 — install binary
- `dot_config/nix/darwin/homebrew.nix:44` — add `"rtk"` to brews list under "Tools not in nixpkgs".

### Phase 2 — capture init artifacts (exact set TBD until `rtk init -g` runs)
- `private_dot_claude/RTK.md` (new, expected) — instructions RTK drops into `~/.claude/RTK.md`.
- `private_dot_claude/settings.json` — merge RTK's hook entry into existing `hooks` block.
- `private_dot_claude/hooks/rtk-*.sh` (maybe) — only if RTK ships an external hook script.
- `dot_config/rtk/config.toml` (new) — captured config with telemetry disabled.
- `private_dot_claude/.rtk-version` (new) — version marker for drift checks.
- `.chezmoiignore` — add `!.claude/RTK.md` and any other newly-tracked `.claude/` files.

## Steps

1. Edit `homebrew.nix`, add `"rtk"`. `darwin-rebuild switch --flake ~/.config/nix#bearcat`. Verify `which rtk && rtk --version`.
2. Snapshot: `cp -a ~/.claude /tmp/claude-before` and `cp ~/.claude/settings.json /tmp/settings-before.json`.
3. Run `rtk init -g`.
4. `rtk telemetry disable`.
5. Diff. Show user the produced files and the `settings.json` mutation. **Get approval before continuing.**
6. Move artifacts into `private_dot_claude/` source tree. Hand-merge `settings.json` (don't overwrite).
7. Capture `~/.config/rtk/config.toml` to `dot_config/rtk/config.toml` if present.
8. Write `rtk --version` output to `private_dot_claude/.rtk-version`.
9. Update `.chezmoiignore` with `!`-negation lines.
10. Verify reproducibility: `rtk init -g --uninstall`, `chezmoi apply`, confirm `rtk` works.

## Verification

- `which rtk` → homebrew path after Phase 1.
- `chezmoi diff` empty after Phase 2's final apply.
- Next Claude Code Bash call to a supported command shows compressed output.

## Unresolved

- Phase 2 file set unknown until `rtk init -g` runs (handled by step 5 review gate).
- Hook style: inline command in settings.json, or external script under `~/.claude/hooks/`?
