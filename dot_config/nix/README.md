# Nix Darwin / Home Manager

## Hosts

`flake.nix` defines:

| Target | Arch | Notes |
|--------|------|-------|
| `.#bearcat` | x86_64-darwin | Intel home desktop (named host) |
| `.#blackbird` | aarch64-darwin | Apple Silicon work laptop (named host) |
| `.#aarch64-darwin` | aarch64-darwin | generic fallback — any Apple Silicon Mac, no custom config |
| `.#x86_64-darwin` | x86_64-darwin | generic fallback — any Intel Mac |
| `.#default` | aarch64-darwin | guaranteed working base for an unnamed machine |

A machine only needs an entry under `hosts/<name>/` + `namedHosts` in `flake.nix`
when it requires a corner-case override (hostname, per-machine app groups). The
shared `./darwin` config is a complete, working system on its own, so a fallback
target is enough to bring a new machine up.

## Bootstrap (fresh machine)

After installing nix and running `chezmoi apply` (which materializes this dir to
`~/.config/nix`), let the resolver pick the target automatically — the named host
if one matches this machine's hostname, else the per-arch fallback:

```
~/.config/nix/scripts/bootstrap.sh
```

Or by hand, choosing the target yourself:

```
cd ~/.config/nix
sudo nix run "nix-darwin/master#darwin-rebuild" -- switch --flake ".#default" -L
```

(The first switch installs `darwin-rebuild` into PATH; before that you must use
the `nix run` form. `sudo` strips PATH, so use an absolute path to `nix` if it
isn't found: `/nix/var/nix/profiles/default/bin/nix`.)

## Apply (day-to-day)

```
# After the first switch, darwin-rebuild is on PATH:
darwin-rebuild switch --flake ~/.config/nix#bearcat   # or #blackbird

# Or the sudo-wrapper alias:
nixhome-switch
```

## Diff and Cleanup

```
# Cleanup unused packages
brew bundle cleanup --file "$HOMEBREW_BUNDLE_FILE"

These must be done in a FRESH shell:

# What packages are installed but not in the Brewfile for nix-darwin
comm -13 \
  <(brew bundle list --formula --file "$HOMEBREW_BUNDLE_FILE" | sort) \
  <(brew list --formula --installed-on-request | sort)

# What casks are installed but not in the Brewfile for nix-darwin
comm -13 \
  <(brew bundle list --cask --file "$HOMEBREW_BUNDLE_FILE" | sort) \
  <(brew list --cask | sort)
```

## History

Dotfiles have been built up over the years.

Nix home manager bits originally from (https://github.com/nebrelbug/nix-macos-starter).

## Project Structure

```
nix/
├── flake.nix                     # inputs + darwinConfigurations (mkDarwin helper)
├── darwin/                       # system-level modules (imported by default.nix)
│   ├── default.nix               # core macOS config; wires Home Manager + ../common
│   ├── settings.nix              # macOS UI/UX defaults
│   ├── homebrew.nix              # brews + the universal (shared) cask set
│   └── cask-groups.nix           # named cask groups composed per host
├── common/                       # Home Manager (user) modules
│   ├── default.nix               # entry point (imports packages/git/shell/mise/…)
│   ├── packages.nix              # CLI tools
│   ├── git.nix  shell.nix  mise.nix  direnv.nix  emacs.nix
├── hosts/                        # per-machine corner-case overrides
│   ├── bearcat/configuration.nix     # home: pulls personal/creative/heavy groups
│   └── blackbird/configuration.nix   # work: lean; disables nix-homebrew
└── scripts/
    ├── bootstrap.sh              # auto-select + first switch on a new machine
    ├── nix-eval-check.sh  chezmoi-report.sh  darwin-report.sh
```

## Customization

- **CLI tool** → `common/packages.nix`
- **GUI app (all machines)** → add to a shared group in `darwin/cask-groups.nix`, included by `darwin/homebrew.nix`
- **GUI app (one machine)** → pull a group (or add a cask) in that `hosts/<host>/configuration.nix`
- **macOS default** → `darwin/settings.nix`
- **Dev runtime (node/python version)** → `common/mise.nix`

## Troubleshooting

- **"Command not found" after first switch** → open a fresh shell (PATH/aliases land via Home Manager's generated zshrc).
- **`sudo nix: command not found`** → `sudo` sanitizes PATH; use the absolute nix path `/nix/var/nix/profiles/default/bin/nix`.
- **Homebrew bundle looks frozen** → it isn't; `--verbose` (set in `homebrew.onActivation.extraFlags`) streams per-package progress. Heavy casks are just large.
- **nix-homebrew can't adopt an existing Homebrew** → see the override in `hosts/blackbird/configuration.nix` (`nix-homebrew.enable = lib.mkForce false`).
