# Nix Darwin / Home Manager

## Apply the Configuration

```
# Build and switch to the configuration
darwin-rebuild switch --flake .#my-macbook

# Or use the alias after initial setup
nix-switch
```

## Bootstrap

```
cd ~/.config/nix
sudo nix run "nix-darwin/master#darwin-rebuild" -- switch --flake ".#my-macbook" -L
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

A beginner-friendly Nix configuration for macOS using flakes, nix-darwin, Home Manager, and Mise.

## Project Structure

```
nix-macos-starter/
├── flake.nix                    # Main flake configuration and inputs
├── darwin/
│   ├── default.nix              # Core macOS system configuration
│   ├── settings.nix             # macOS UI/UX preferences and defaults
│   └── homebrew.nix             # GUI applications via Homebrew
├── home/
│   ├── default.nix              # Home Manager configuration entry point
│   ├── packages.nix             # Package declarations and mise setup
│   ├── git.nix                  # Git configuration
│   ├── shell.nix                # Shell configuration
│   └── mise.nix                 # Development runtime management
└── hosts/
    └── my-macbook/
        ├── configuration.nix    # Host-specific packages and settings
        └── shell-functions.sh   # Custom shell scripts
```

## Customization

**Add CLI Tools**: Edit `home/packages.nix` packages array  
**Add GUI Apps**: Edit `darwin/homebrew.nix` casks array  
**Add Development Tools**: Add `${pkgs.mise}/bin/mise use --global tool@version` to `home/mise.nix` activation script  
**Host-Specific Config**: Use `hosts/my-macbook/configuration.nix` for machine-specific packages/apps and `custom-scripts.sh` for shell scripts

## Troubleshooting

**"Command not found"**: Restart terminal  
**Permission denied**: Use `sudo darwin-rebuild switch --flake .#my-macbook`  
**Homebrew apps not installing**: nix-homebrew handles this automatically; ensure `/opt/homebrew/bin` in PATH  
**Git config not applying**: Replace all `YOUR_*` placeholders, re-run darwin-rebuild
