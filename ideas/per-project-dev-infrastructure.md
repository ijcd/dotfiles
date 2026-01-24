# Per-Project Development Infrastructure (Historical Reference)

This document captures the per-project isolated development infrastructure setup used prior to moving to a shared services model. Preserved for reference if we ever want to return to this approach.

## Overview

The setup provides complete isolation between multiple Elixir/Phoenix projects on the same machine:
- Each project gets its own loopback IP (127.0.0.10, .20, .30, etc.)
- All projects can run on port 4000 simultaneously
- Each project runs its own PostgreSQL instance
- DNS resolution via dnsmasq provides pretty URLs

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│ .envrc (direnv)                                     │
│ - Loads flake.nix → devenv.nix                      │
│ - Sets OVERMIND_AUTO_RESTART=phoenix                │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ devenv (nix)                                        │
│ - Elixir 1.18, Node 22, PostgreSQL 16               │
│ - Listen on 127.0.0.10:5432 (TCP)                   │
│ - Includes overmind, tmux, chromedriver             │
└─────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────┬──────────────┐
│ overmind + Procfile                  │ Config       │
│ ┌──────────────────────────────────┐ │              │
│ │ devenv: devenv up                │ │ .overmind.env│
│ │ phoenix: iex -S mix phx.server   │ │ .tmux.conf   │
│ │ postgres-alerts: tail logs       │ │              │
│ └──────────────────────────────────┘ │              │
└──────────────────────────────────────┴──────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ Development Endpoints                               │
│ Phoenix:      http://theliberties.test:4000         │
│ PostgreSQL:   postgres.theliberties.test:5432       │
│ LiveDebugger: http://theliberties.test:4007         │
└─────────────────────────────────────────────────────┘
```

## Network Configuration

### Per-Project IP Assignment
- **theliberties**: 127.0.0.10
- **project2**: 127.0.0.20
- **project3**: 127.0.0.30
- etc.

### macOS Loopback Setup (One-Time)

macOS requires loopback aliases and PF NAT rules for hairpin routing:

```bash
# 1. Create loopback alias (add to shell profile or run at boot)
sudo ifconfig lo0 alias 127.0.0.10

# 2. Create PF NAT rule
echo 'nat on lo0 from 127.0.0.10 to 127.0.0.10 -> 127.0.0.1' | sudo tee /etc/pf.anchors/loopback_fix

# 3. Add anchor to /etc/pf.conf (insert after existing nat-anchor line):
#    nat-anchor "loopback_fix"
#    load anchor "loopback_fix" from "/etc/pf.anchors/loopback_fix"

# 4. Load and enable PF
sudo pfctl -f /etc/pf.conf
sudo pfctl -e
```

### dnsmasq Setup (Pretty URLs)

```bash
brew install dnsmasq

# Add to /opt/homebrew/etc/dnsmasq.conf:
address=/theliberties.test/127.0.0.10
address=/postgres.theliberties.test/127.0.0.10

# Create resolver for .test TLD
sudo mkdir -p /etc/resolver
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/test

sudo brew services start dnsmasq
```

## Configuration Files

### flake.nix

Nix flake entry point - loads devenv.nix for all platforms:

```nix
{
  description = "Liberties - web application";

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

Defines languages, services, and packages:

```nix
{ pkgs, config, ... }:
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
      { name = "liberties_dev"; }
      { name = "liberties_test"; }
    ];
    # Listen on project-specific IP (postgres.theliberties.test -> 127.0.0.10)
    listen_addresses = "127.0.0.10";
    port = 5432;
    settings = {
      logging_collector = "on";
      log_directory = "log";
      log_filename = "postgresql.log";
      log_truncate_on_rotation = "off";
    };
  };

  env.ERL_AFLAGS = "-kernel shell_history enabled";

  # For Phoenix live reload on Linux
  packages = [
    pkgs.flyctl
    pkgs.overmind
    pkgs.tmux  # Same version overmind uses, avoids version mismatch
    pkgs.chromedriver  # For Wallaby E2E tests
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    pkgs.inotify-tools
  ];
}
```

**Key points:**
- PostgreSQL listens on project-specific IP (127.0.0.10), not localhost
- tmux is included to match overmind's version (prevents socket errors)
- chromedriver for Wallaby E2E tests

### Procfile

Three processes managed by overmind:

```
devenv: devenv up
phoenix: sleep 3 && iex -S mix phx.server
postgres-alerts: sleep 5 && tail -F .devenv/state/postgres/log/postgresql.log 2>/dev/null | while read line; do echo "$line"; printf '\a'; done
```

- **devenv**: Starts nix services (postgres) via process-compose TUI
- **phoenix**: Waits 3s for postgres, then starts interactive iex shell
- **postgres-alerts**: Tails postgres logs, bells on new entries (useful for catching errors)

### .envrc

Direnv configuration - loads nix environment:

```bash
use flake . --impure

# Load local overrides if present
if [ -f .envrc.local ]; then
  source_env .envrc.local
fi
# AUTO_RESTART implies CAN_DIE (CAN_DIE takes precedence and disables restart)
export OVERMIND_AUTO_RESTART=phoenix
```

**Important:** `OVERMIND_AUTO_RESTART=phoenix` makes overmind restart phoenix if it crashes. Don't use with `OVERMIND_CAN_DIE` (they conflict).

### .overmind.env

Overmind-specific settings:

```
OVERMIND_TMUX_CONFIG=.tmux.overmind.conf
OVERMIND_NO_PORT=1
```

- Custom tmux config to suppress devenv TUI spam
- `NO_PORT=1` prevents overmind from overriding PORT env var

### .tmux.overmind.conf

Suppresses activity monitoring spam from process-compose:

```bash
# Source main tmux config
source-file ~/.config/tmux/tmux.conf

# Disable monitor-activity for devenv window (process-compose TUI constantly redraws)
# Fires when client connects, window 1 (devenv) exists by then
set-hook -g client-attached 'selectw -t 1 ; setw monitor-activity off ; selectw -t 2'
```

### config/dev.exs (Relevant Portions)

Phoenix and database configuration using project-specific IP:

```elixir
import Config

# Project-specific loopback IP for multi-project dev
# theliberties.test -> 127.0.0.10 (via dnsmasq + PF NAT)
dev_ip = {127, 0, 0, 10}
dev_host = "theliberties.test"

config :ash, policies: [show_policy_breakdowns?: true]

# LiveDebugger (uses top-level :ip/:port, not nested http:)
config :live_debugger,
  ip: dev_ip,
  port: 4007,
  external_url: "http://#{dev_host}:4007"

# Configure your database
# Uses TCP on project-specific IP (postgres.theliberties.test -> 127.0.0.10)
config :liberties, Liberties.Repo,
  username: System.get_env("USER"),
  database: "liberties_dev",
  hostname: "postgres.theliberties.test",
  port: 5432,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :liberties, LibertiesWeb.Endpoint,
  url: [host: dev_host, port: 4000],
  http: [ip: dev_ip, port: 4000],
  check_origin: ["//#{dev_host}"],
  code_reloader: true,
  debug_errors: true,
  # ...
```

### scripts/restart-phoenix

Handles restarting phoenix via overmind/tmux (iex BREAK menu requires special handling):

```bash
#!/usr/bin/env bash
# Restart Phoenix via overmind/tmux
# Handles the iex BREAK menu by sending 'a' to abort
#
# Requires: devenv shell (tmux from devenv.nix must match overmind's version)

set -e

if [ ! -S .overmind.sock ]; then
  echo "No .overmind.sock found - is overmind running? Are you in the project directory?"
  exit 1
fi

# Project-specific session name
PROJECT="liberties-www"

# Get socket name from running overmind tmux
SOCKET_NAME=$(ps aux | grep "tmux -C -L overmind-${PROJECT}-" | grep -v grep | head -1 | grep -oE "overmind-${PROJECT}-[A-Za-z0-9_-]+" | head -1)

if [ -z "$SOCKET_NAME" ]; then
  echo "Could not find overmind tmux socket for $PROJECT"
  exit 1
fi

echo "Socket: $SOCKET_NAME"

# Send Ctrl-C to trigger BREAK menu, then 'a' + Enter to abort
if ! TMUX="" tmux -L "$SOCKET_NAME" send-keys -t "${PROJECT}:phoenix" C-c 2>&1; then
  echo ""
  echo "Error: tmux command failed. Likely version mismatch."
  echo "Your tmux: $(tmux -V)"
  echo "Fix: run 'direnv reload' or cd into the project directory first."
  exit 1
fi
sleep 0.5
TMUX="" tmux -L "$SOCKET_NAME" send-keys -t "${PROJECT}:phoenix" a Enter

echo "Sent abort to phoenix. Overmind should restart it."
```

**Why not `overmind restart phoenix`?** It sends SIGTERM, which iex catches and shows the BREAK menu, waiting for input. This script sends the keystrokes to abort cleanly.

## Troubleshooting

### tmux Version Mismatch

**Symptom:** `server exited unexpectedly` when running tmux commands

**Cause:** Home-manager may have a different tmux version than devenv

**Fix:** Both `pkgs.overmind` and `pkgs.tmux` are in devenv.nix. Run `direnv reload` to ensure you're using the devenv tmux.

### PostgreSQL Not Starting

**Symptom:** Phoenix can't connect to database

**Check:**
1. Is devenv running? `overmind connect devenv`
2. Is postgres listening? `lsof -i :5432`
3. Check logs: `tail .devenv/state/postgres/log/postgresql.log`

### Can't Access http://theliberties.test:4000

**Check:**
1. Loopback alias exists: `ifconfig lo0 | grep 127.0.0.10`
2. PF is enabled: `sudo pfctl -s info | grep Status`
3. dnsmasq resolves: `dig theliberties.test @127.0.0.1`

## Design Decisions

1. **TCP over Unix Socket**: Uses TCP on project-specific IP instead of unix sockets to support multiple projects on same machine, all using port 4000

2. **DNS Resolution**: Dev uses `postgres.theliberties.test` hostname for configuration flexibility; test uses direct IP for speed

3. **Tmux Version Matching**: Both overmind and tmux from same devenv.nix to prevent socket errors

4. **Auto-restart Phoenix Only**: Only phoenix auto-restarts; postgres/devenv don't to prevent cascade failures

5. **Process-Compose Integration**: .tmux.overmind.conf disables activity monitoring to prevent spam from process-compose TUI

## Trade-offs

### Pros
- Complete isolation between projects
- All projects can run simultaneously on port 4000
- Pretty URLs via dnsmasq
- Each project manages its own postgres version

### Cons
- Complex macOS setup (loopback aliases, PF NAT, dnsmasq)
- Resource overhead (each project runs its own postgres)
- New project requires adding loopback alias + dnsmasq entry
- Can't easily share data between projects
- Debugging network issues is more complex
