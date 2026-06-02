---
name: scaffold-phoenix-ash
description: Use when creating a new Phoenix 1.8 + Ash 3.x project with devenv, PostgreSQL, and standard quality tooling. Triggers on new project setup, greenfield scaffold, or "create a new Phoenix app".
---

# Scaffold Phoenix + Ash Project

Generate a Phoenix 1.8 + Ash 3.x app with devenv (flake-based), PostgreSQL via Unix socket, and a standard quality toolchain.

## Prerequisites

- devenv.sh installed
- direnv installed
- Mix available (via existing devenv shell or system install)
- `mix archive.install hex igniter_new` (one-time)

## Step 1: Generate with Igniter

From the **parent directory** of where the project should live:

```bash
mix igniter.new APP_NAME \
  --install ash,ash_postgres,ash_phoenix \
  --with phx.new --no-ecto
```

If scaffolding into an existing repo (already has .git), generate into a temp dir and move files in:

```bash
cd /tmp && mix igniter.new APP_NAME --install ash,ash_postgres,ash_phoenix --with phx.new --no-ecto
# Then copy files into existing repo, preserving .git, CLAUDE.md, plans/, etc.
```

## Step 2: devenv Files

### flake.nix

```nix
{
  description = "APP_DESCRIPTION";

  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv.url = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, devenv, ... }@inputs:
    let
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [ ./devenv.nix ];
          };
        });
    };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };
}
```

### devenv.nix

```nix
{ pkgs, ... }:
{
  languages.elixir = {
    enable = true;
    package = pkgs.elixir_1_18;
  };

  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_22;
  };

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_16;
    initialDatabases = [
      { name = "APP_NAME_dev"; }
      { name = "APP_NAME_test"; }
    ];
    listen_addresses = "";  # Unix socket only — no port conflicts
    settings = {
      log_destination = "stderr";
      logging_collector = "on";
      log_directory = "log";
      log_filename = "postgresql.log";
    };
  };

  env.ERL_AFLAGS = "-kernel shell_history enabled";

  # macOS Sequoia 15.4+ firewall blocks unsigned binaries on loopback aliases
  # (127.0.0.10+). Treehouse uses per-branch loopback IPs, so beam.smp must
  # be ad-hoc codesigned. Only prompts sudo when actually unsigned.
  scripts.sign-beam.exec = pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
    BEAM=$(echo $(dirname $(which erl))/../lib/erlang/erts-*/bin/beam.smp)
    if [ -f "$BEAM" ] && ! codesign -v "$BEAM" 2>/dev/null; then
      echo "beam.smp is unsigned — Treehouse needs it signed for macOS firewall."
      echo "Signing $BEAM (requires sudo for nix store write)..."
      sudo cp "$BEAM" "$BEAM.bak"
      sudo cp "$BEAM.bak" "$BEAM.tmp"
      sudo codesign -s - -f "$BEAM.tmp"
      sudo mv "$BEAM.tmp" "$BEAM"
      sudo rm "$BEAM.bak"
      echo "Done. beam.smp is now ad-hoc signed."
    else
      echo "beam.smp already signed."
    fi
  '';

  process.manager.implementation = "overmind";
  processes.phoenix.exec = "while [ ! -S $PGHOST/.s.PGSQL.5432 ]; do sleep 0.2; done && mix ash.setup && bin/dev";

  packages = [
    pkgs.overmind
    pkgs.tmux
    pkgs.watchexec
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    pkgs.inotify-tools
  ];
}
```

### .envrc

```bash
use flake . --impure

# Load local overrides if present
if [ -f .envrc.local ]; then
  source_env .envrc.local
fi
```

## Step 3: .gitignore

```gitignore
# Devenv
.devenv/
.devenv.flake.nix

# Direnv
.direnv/

# Local overrides
.envrc.local

# Elixir/Phoenix
/_build/
/cover/
/deps/
/doc/
/.fetch
erl_crash.dump
*.ez
*.beam
*.plt
*.pot

# Assets
/priv/static/assets/
/assets/node_modules/

# Database
*.db
*.db-*

# Editor/IDE
.elixir_ls/
.lexical/
.vscode/
*.swp
*~
.worktrees/
```

## Step 4: Quality Tooling

### Add deps to mix.exs

```elixir
# In deps/0:
{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
{:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
{:hammox, "~> 0.7", only: :test},
```

### mix precommit task

Create `lib/mix/tasks/precommit.ex`:

```elixir
defmodule Mix.Tasks.Precommit do
  use Mix.Task

  @shortdoc "Run full quality pipeline"

  @impl Mix.Task
  def run(_args) do
    cmds = [
      {"compile", ["--warnings-as-errors"]},
      {"deps.unlock", ["--check-unused"]},
      {"deps.audit", []},
      {"format", ["--check-formatted"]},
      {"credo", ["--strict"]},
      {"sobelow", ["--exit", "--threshold", "medium"]},
      {"test", []}
    ]

    Enum.each(cmds, fn {task, args} ->
      IO.puts("\n==> mix #{task} #{Enum.join(args, " ")}")
      Mix.Task.rerun(task, args)
    end)
  end
end
```

### .credo.exs

Disable checks that conflict with Ash DSL macros: SpaceAroundOperators, CyclomaticComplexity, FunctionArity, LongQuoteBlocks, MatchInCondition, TagTODO, ModuleDoc. Set nesting max to 3.

### .sobelow-conf

Ignore Config.CSP for local-only apps.

## Step 5: Repo Config (for Ash)

In `config/config.exs`, ensure:

```elixir
config :APP_NAME, ash_domains: []  # Add domains as built
```

In `config/dev.exs` and `config/test.exs`, configure repo to use Unix socket:

```elixir
config :APP_NAME, APP_MODULE.Repo,
  database: "APP_NAME_dev",
  socket_dir: System.get_env("PGHOST")

# Note: Do NOT set username: "postgres" — devenv creates the current OS user as superuser
```

## Step 6: Optional — Treehouse Path Dep

If the project uses the treehouse library for branch-scoped IPs:

```elixir
{:treehouse, path: "../treehouse"}
```

## Checklist

- [ ] `mix igniter.new` generates app
- [ ] flake.nix + devenv.nix + .envrc created
- [ ] .gitignore covers devenv + Elixir + assets
- [ ] Quality deps added (credo, sobelow, mix_audit, hammox)
- [ ] `mix precommit` task created
- [ ] .credo.exs tuned for Ash
- [ ] .sobelow-conf ignores local-only checks
- [ ] Repo configured for Unix socket postgres
- [ ] `devenv up` starts postgres + phoenix
- [ ] `mix test` passes
- [ ] `mix precommit` passes
