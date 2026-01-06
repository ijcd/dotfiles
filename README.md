# Dotfiles

These are my dotfiles. There are many like them but these ones are mine.

Built up over a few decades of Unix use, starting with zsh in 1995.

## Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Dotfiles | [chezmoi](https://chezmoi.io) | Manage dotfiles across machines |
| System | [nix-darwin](https://github.com/LnL7/nix-darwin) | Declarative macOS configuration |
| Packages | [Home Manager](https://github.com/nix-community/home-manager) | User environment via Nix |
| Shell | [zsh](https://zsh.sourceforge.io) + [Zim](https://zimfw.sh) | Fast, minimal zsh framework |
| Prompt | [Starship](https://starship.rs) | Cross-shell prompt |

## Quick Start

```sh
# Install chezmoi and apply dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ijcd

# Nix setup (if not already installed)
curl -L https://nixos.org/nix/install | sh

# Apply nix-darwin + Home Manager
darwin-rebuild switch --flake ~/.config/nix
```

## Organization

```
~/.local/share/chezmoi/
├── dot_config/
│   ├── nix/              # nix-darwin + Home Manager flake
│   ├── zsh/              # zsh config (zshrc, aliases, functions)
│   └── starship.toml     # prompt config
├── dot_local/
│   └── bin/              # personal scripts (~/.local/bin)
├── dot_gitconfig         # git configuration
├── dot_tmux.conf         # tmux configuration
└── archive/              # historical configs (preserved for posterity)
```

## Scripts

Scripts live in `~/.local/bin` with namespaced prefixes:

| Prefix | Domain |
|--------|--------|
| `git-*` | Git extensions (callable as `git foo`) |
| `docker-*` | Docker helpers |
| `term-*` | Terminal utilities |
| `macos-*` | macOS-specific tools |

## Key Files

| File | Purpose |
|------|---------|
| `dot_config/zsh/zshrc` | Main zsh config |
| `dot_config/zsh/aliases.zsh` | Shell aliases |
| `dot_config/zsh/functions/` | Autoloaded functions |
| `dot_gitconfig` | Git config with aliases |
| `dot_config/nix/flake.nix` | Nix system configuration |

## Useful Commands

```sh
# Chezmoi
chezmoi apply           # Apply changes
chezmoi diff            # See pending changes
chezmoi edit <file>     # Edit a managed file
chezmoi cd              # cd to chezmoi source dir

# Nix
darwin-rebuild switch --flake ~/.config/nix   # Rebuild system
nix flake update                               # Update flake inputs

# Zim
zimfw update            # Update Zim modules
zimfw compile           # Recompile for speed
```

## Tips

- **zmv**: `zmv '(*).txt' '$1.md'` - powerful bulk rename
- **fzf**: `ctrl-r` history, `ctrl-t` files
- **git aliases**: See `git config --get-regexp alias` or `dot_gitconfig`

## History

I've been using zsh since 1995. The dotfiles have evolved through many
incarnations:

1. **1995-2000s**: Scattered `.rc` files, MIT Athena influence
2. **2000s**: Custom module system with symlinks
3. **2010s**: zgen + oh-my-zsh + prezto modules
4. **2024+**: chezmoi + nix-darwin + Home Manager + Zim

See `archive/` for historical configs preserved for posterity, including
my 1995 MIT Xresources, 2000s email infrastructure, and 2010s Ruby setup.
