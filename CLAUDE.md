# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles managed by [chezmoi](https://chezmoi.io), with macOS system state managed by [nix-darwin](https://github.com/LnL7/nix-darwin) + [Home Manager](https://github.com/nix-community/home-manager) (under `dot_config/nix/`). Two config layers, cleanly split: chezmoi handles file content/perms/symlinks; nix handles installed packages and macOS defaults.

## chezmoi filename conventions

Source filenames encode destination metadata. Editing/creating files requires using the right prefix or chezmoi will not place them correctly:

| Prefix | Effect on destination |
|--------|------------------------|
| `dot_foo` | `.foo` |
| `private_foo` | mode `0600` (also applies to dirs as `0700`) |
| `executable_foo` | `+x` bit set |
| `symlink_foo` | symlink (file content is the link target) |
| `run_once_foo.sh` | runs once on `chezmoi apply` |

Prefixes stack and order matters: `private_dot_claude/executable_statusline.sh` → `~/.claude/statusline.sh` (mode 0700 dir, executable file).

**Don't edit destination files directly** (e.g., `~/.zshrc`) — edit the source in this repo, then `chezmoi apply`. Use `chezmoi edit <dest-path>` to open the source for a destination.

## Common commands

```sh
# chezmoi
chezmoi diff              # preview pending changes
chezmoi apply             # apply changes to ~
chezmoi edit <dest>       # edit source for ~/<dest>
chezmoi managed           # list everything chezmoi controls
chezmoi cd                # cd to source dir (this repo)
~/.config/nix/scripts/chezmoi-report.sh [PATH...]  # what's managed vs not

# nix-darwin / Home Manager (host name = bearcat)
darwin-rebuild switch --flake ~/.config/nix#bearcat
nixhome-switch            # alias for the above (sudo wrapper)
nix flake update          # update inputs in flake.lock
~/.config/nix/scripts/darwin-report.sh             # darwin state report

# zsh framework
zimfw update              # update Zim modules
zimfw compile             # recompile for speed
```

Bootstrap on a fresh machine: see `dot_config/nix/README.md` (uses `sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#bearcat`).

## Architecture

### Top-level layout

- `dot_config/nix/` — flake-based nix-darwin + Home Manager system definition
- `dot_config/zsh/` — zsh config (zshrc, aliases, options, autoloaded functions, Zim setup)
- `dot_config/{git,tmux,starship.toml,...}` — per-tool configs
- `dot_local/bin/` — personal scripts, materialized to `~/.local/bin`
- `dot_hammerspoon/` — Hammerspoon Lua config (`init.lua`, Spoons)
- `private_dot_claude/` — global `~/.claude/` config: `private_CLAUDE.md`, `settings.json`, `executable_statusline.sh`, custom `skills/`
- `archive/`, `ideas/`, `plans/`, `docs/` — **ignored by chezmoi** (see `.chezmoiignore`); historical notes, not deployed

### `.chezmoiignore` shape

The ignore file mixes two things: (1) repo-only directories (`archive/`, `plans/`, etc.) that chezmoi must not deploy, and (2) destination paths that chezmoi must not manage even if they exist in the source tree. The `.claude/*` block uses `!`-negation to track only specific files (`CLAUDE.md`, `settings.json`, `.credentials.json`, `statusline.sh`, `skills`) while ignoring the rest of the local AI state directory. When adding new tracked files under `.claude/`, add a matching `!.claude/<name>` line.

### nix flake structure (`dot_config/nix/`)

- `flake.nix` — inputs (nixpkgs unstable, home-manager, nix-darwin, emacs-overlay, nix-homebrew) and `darwinConfigurations.<host>` outputs. `primaryUser = "ijcd"` is hardcoded here.
- `darwin/` — system-level modules, all imported by `darwin/default.nix`:
  - `homebrew.nix` (declarative brew bundle), `settings.nix` (macOS defaults), `local-dev.nix`, `postgres.nix`, `performance.nix`, `nix-store-fallback.nix`
- `common/` — Home Manager (user-level) modules imported via `home-manager.users.${primaryUser}`: `packages.nix`, `git.nix`, `shell.nix`, `mise.nix`, `direnv.nix`, `emacs.nix`
- `hosts/<hostname>/configuration.nix` — host-specific overrides. Currently only `bearcat` exists. Add a new host by creating `hosts/<name>/` and a new `darwinConfigurations.<name>` block in `flake.nix`.
- `scripts/` — sourceable helper scripts (chezmoi/darwin reports)

Where to add things:
- CLI tool → `common/packages.nix`
- GUI app → `darwin/homebrew.nix` (casks)
- macOS UI default → `darwin/settings.nix`
- Dev runtime (node, python version) → `common/mise.nix`
- Per-machine package or override → `hosts/<host>/configuration.nix`

Notable nix quirks documented in comments: nix is installed externally (`nix.enable = false`); some packages disabled on `x86_64-darwin` (folly/watchman build failures); `mise` comes from homebrew because the nix derivation is broken on x86_64-darwin.

### zsh layering

`dot_config/zsh/zshrc` loads in order: Zim framework → Home Manager-generated `~/.local/share/hm-zsh/.zshrc` (starship, direnv, fzf, zoxide hooks) → `tools.zsh` fallback → `options.zsh` → `aliases.zsh` → `interactive.zsh`. Autoloaded functions live in `functions/`; non-autoloaded support sourced from `support/`. Zim modules declared in `zimrc`.

### Scripts in `dot_local/bin/`

Namespaced by prefix: `git-*` (callable as `git foo` git extensions), `docker-*`, `term-*`, `macos-*`, `dns-*`, `net-*`, `ssh-*`. ~70 scripts total. The `executable_` prefix on source filenames is what makes them runnable after `chezmoi apply`.

## Working in this repo

- For a question like "how is X configured?" — read source in this repo; **don't** read the destination under `~`. The destination is generated.
- After editing a managed file, run `chezmoi diff` to confirm the change before `chezmoi apply`.
- Adding a new file under an already-managed directory: name it with chezmoi prefixes for the perms/transforms you want, then `chezmoi apply`. No registration step.
- Removing a managed file: delete from source AND run `chezmoi apply` (which will offer to remove the destination), or add it to `.chezmoiignore`.
- Changes to `dot_config/nix/**` require `darwin-rebuild switch --flake ~/.config/nix#bearcat` to take effect, not `chezmoi apply`. (chezmoi materializes the flake source; nix-darwin acts on it.)
- The user's global `~/.claude/CLAUDE.md` lives at `private_dot_claude/private_CLAUDE.md` in this repo. Edit there, then `chezmoi apply`.
