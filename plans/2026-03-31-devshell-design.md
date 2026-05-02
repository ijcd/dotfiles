# devshell — quick nix dev shells

## Problem

No fast way to: (a) scaffold a flake.nix devShell for a project, (b) run one-off commands in a language environment, (c) bootstrap new projects without global tool pollution.

Existing tools (devbox, devenv) add their own dependencies and file formats. We already have nix + direnv — just need templates and a thin wrapper.

## Command Interface

```
devshell init <ecosystem>   # scaffold flake.nix + .envrc into cwd
devshell run <ecosystem>    # ephemeral interactive shell, no files created
devshell list               # show available ecosystems
```

### `init` behavior

1. Refuse if `flake.nix` exists (print warning, exit 1)
2. Copy `~/.config/devshell-templates/<ecosystem>/flake.nix` to `./flake.nix`
3. Create `.envrc` with `use flake` if not already present
4. Run `direnv allow`
5. Print summary of what was created

### `run` behavior

1. Map ecosystem name to core package list (same packages as template's `buildInputs`)
2. `nix shell nixpkgs#<pkg1> nixpkgs#<pkg2> ... -c zsh`
3. No files touched — purely ephemeral
4. Package mapping is a case statement inside the devshell function

### `list` behavior

1. List directories in `~/.config/devshell-templates/`
2. Print names, one per line

## File Locations (chezmoi)

- `dot_config/devshell-templates/<ecosystem>/flake.nix` — per-ecosystem template
- `dot_config/devshell-templates/envrc` — shared `.envrc` (contains `use flake`)
- `dot_config/zsh/functions/devshell` — zsh autoload function

## Ecosystem Templates

Each `flake.nix` is standalone with:
- `description` field
- `nixpkgs` as sole input
- Single `devShells.default` output
- `shellHook` for ecosystem-specific env vars

### elixir
- **Core:** elixir, erlang, hex, rebar3
- **Extras:** inotify-tools, postgresql (psql), locale settings
- **shellHook:** LANG=en_US.UTF-8, ERL_AFLAGS for shell history

### go
- **Core:** go, gopls
- **Extras:** delve, golangci-lint
- **shellHook:** GOPATH=$PWD/.go, PATH includes GOPATH/bin

### rust
- **Core:** rustc, cargo, rustfmt, clippy
- **Extras:** rust-analyzer, pkg-config, openssl
- **shellHook:** —

### python
- **Core:** python3, pip, virtualenv
- **Extras:** black, ruff, mypy
- **shellHook:** VIRTUAL_ENV hint, PIP_PREFIX

### ruby
- **Core:** ruby, bundler
- **Extras:** solargraph, libyaml
- **shellHook:** GEM_HOME=$PWD/.gems, PATH includes GEM_HOME/bin

### typescript
- **Core:** nodejs, corepack
- **Extras:** typescript, eslint
- **shellHook:** —

### zig
- **Core:** zig, zls
- **Extras:** —
- **shellHook:** —

### java
- **Core:** jdk, maven
- **Extras:** gradle
- **shellHook:** JAVA_HOME

## Design Decisions

- **Plain template files over nix flake templates:** easier to edit, no nix store ceremony, supports string replacement if needed later
- **Refuse on existing flake.nix:** safest default, no accidental overwrites
- **Shared .envrc:** all ecosystems use the same `use flake` pattern
- **Autoloaded zsh function:** matches existing `dot_config/zsh/functions/` pattern (my-help, upd, etc.)
- **No extra dependencies:** only nix + direnv, both already installed
