# dev-ip: Local Development IP Manager

## Overview

A tool to manage isolated local development environments with:
- Per-project/branch IP allocation from a pool (127.0.0.10-99)
- Automatic loopback alias creation
- mDNS/DNS for nice hostnames (branch-name.test or branch-name.local)
- Optional HTTPS with auto-generated certificates
- Language agnostic - works with Phoenix, Rails, Node, Go, etc.

## Inspiration

- [puma-dev](https://github.com/puma/puma-dev) - Go tool for Ruby, handles DNS + proxy + HTTPS
- [localdev](https://github.com/braceio/localdev) - DNS + reverse proxy for multi-domain dev
- [loopback-manager](https://github.com/takah/loopback-manager) - IP allocation for Docker Compose

## Architecture Options

### Option A: Elixir Hex Package (`dev_ip`)

Lightweight library for Phoenix projects. Relies on external setup for loopback aliases.

```
┌─────────────────────────────────────────────────────────────────┐
│ nix-darwin (privileged, runs at boot)                          │
│ ├── Loopback aliases: 127.0.0.10-99                            │
│ ├── PF hairpin NAT rules                                       │
│ └── Shared Postgres                                            │
└─────────────────────────────────────────────────────────────────┘
                              ↑
┌─────────────────────────────────────────────────────────────────┐
│ dev_ip (Hex package, runs in Phoenix app)                      │
│ ├── SQLite registry (~/.local/share/dev_ip/registry.db)        │
│ ├── IP allocation from pool                                    │
│ ├── mDNS announcement (dns-sd)                                 │
│ └── Phoenix endpoint configuration                             │
└─────────────────────────────────────────────────────────────────┘
```

**Pros**: Simple, Phoenix-native, no daemon
**Cons**: Needs nix-darwin for IP setup, Phoenix-only

### Option B: Go/Rust Daemon (`dev-ip`)

Privileged daemon that handles everything.

```
┌─────────────────────────────────────────────────────────────────┐
│ dev-ip daemon (privileged, runs as launchd service)            │
│ ├── Creates loopback aliases on demand                         │
│ ├── Manages PF hairpin rules                                   │
│ ├── Runs DNS server for .test domains                          │
│ ├── Optional: reverse proxy with HTTPS                         │
│ └── SQLite registry for allocations                            │
└─────────────────────────────────────────────────────────────────┘
                              ↑
┌─────────────────────────────────────────────────────────────────┐
│ dev-ip CLI (unprivileged)                                      │
│ ├── dev-ip register my-branch                                  │
│ ├── dev-ip start (in project dir)                              │
│ └── dev-ip list / dev-ip release                               │
└─────────────────────────────────────────────────────────────────┘
                              ↑
┌─────────────────────────────────────────────────────────────────┐
│ Language integrations (optional, thin wrappers)                │
│ ├── dev_ip (Elixir) - calls CLI                                │
│ ├── dev-ip-rails (Ruby) - calls CLI                            │
│ └── etc.                                                        │
└─────────────────────────────────────────────────────────────────┘
```

**Pros**: Language agnostic, handles all privileged ops, single source of truth
**Cons**: More complex, daemon to manage

---

## Option A: Elixir Hex Package

### Installation

```elixir
# mix.exs
defp deps do
  [
    {:dev_ip, "~> 0.1", only: :dev}
  ]
end
```

### Configuration

```elixir
# config/dev.exs
config :dev_ip,
  registry_path: "~/.local/share/dev_ip/registry.db",
  ip_range: {10, 99},  # 127.0.0.10 - 127.0.0.99
  domain: "local",     # .local (mDNS) or .test (requires dnsmasq)
  auto_announce: true  # mDNS announcement
```

### Usage

```elixir
# config/runtime.exs
if config_env() == :dev do
  DevIp.Phoenix.configure!(:my_app, MyAppWeb.Endpoint)
end
```

### Module Structure

```
dev_ip/
├── lib/
│   ├── dev_ip.ex
│   │   # Main API
│   │   # - allocate(branch) :: {:ok, ip} | {:error, reason}
│   │   # - release(branch) :: :ok
│   │   # - get_or_allocate(branch) :: {:ok, ip}
│   │   # - list() :: [%Allocation{}]
│   │   # - info(branch) :: %Allocation{} | nil
│   │
│   ├── dev_ip/
│   │   ├── registry.ex
│   │   │   # SQLite storage
│   │   │   # - init_db()
│   │   │   # - insert_allocation(branch, ip)
│   │   │   # - find_by_branch(branch)
│   │   │   # - find_by_ip(ip)
│   │   │   # - delete_allocation(branch)
│   │   │   # - list_allocations()
│   │   │   # - next_available_ip()
│   │   │   # - update_heartbeat(branch)
│   │   │   # - cleanup_stale(threshold_minutes)
│   │   │
│   │   ├── allocator.ex
│   │   │   # IP allocation logic
│   │   │   # - GenServer managing allocations
│   │   │   # - Handles concurrent requests
│   │   │   # - Heartbeat updates
│   │   │
│   │   ├── mdns.ex
│   │   │   # mDNS announcement via dns-sd
│   │   │   # - announce(hostname, ip, port) :: {:ok, pid}
│   │   │   # - stop(pid)
│   │   │   # - Wraps dns-sd -P command
│   │   │
│   │   ├── phoenix.ex
│   │   │   # Phoenix integration
│   │   │   # - configure!(app, endpoint_module)
│   │   │   # - Detects git branch
│   │   │   # - Allocates IP
│   │   │   # - Configures endpoint
│   │   │   # - Starts mDNS announcer
│   │   │
│   │   └── application.ex
│   │       # OTP Application
│   │       # - Starts Registry
│   │       # - Starts Allocator
│   │       # - Cleanup stale on start
│   │
│   └── mix/tasks/
│       ├── dev_ip.list.ex      # mix dev_ip.list
│       ├── dev_ip.info.ex      # mix dev_ip.info
│       ├── dev_ip.release.ex   # mix dev_ip.release <branch>
│       └── dev_ip.cleanup.ex   # mix dev_ip.cleanup
│
├── mix.exs
├── README.md
└── test/
```

### SQLite Schema

```sql
-- ~/.local/share/dev_ip/registry.db

CREATE TABLE IF NOT EXISTS allocations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  branch TEXT UNIQUE NOT NULL,
  ip TEXT UNIQUE NOT NULL,
  hostname TEXT NOT NULL,
  port INTEGER DEFAULT 4000,
  pid INTEGER,                    -- OS PID for liveness
  project_path TEXT,              -- Absolute path to project
  allocated_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);

CREATE INDEX idx_allocations_branch ON allocations(branch);
CREATE INDEX idx_allocations_ip ON allocations(ip);
CREATE INDEX idx_allocations_last_seen ON allocations(last_seen_at);

CREATE TABLE IF NOT EXISTS config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Default config
INSERT OR IGNORE INTO config (key, value) VALUES ('ip_range_start', '10');
INSERT OR IGNORE INTO config (key, value) VALUES ('ip_range_end', '99');
INSERT OR IGNORE INTO config (key, value) VALUES ('stale_threshold_minutes', '30');
```

### Key Implementation Details

#### Branch Detection

```elixir
defmodule DevIp.Git do
  def current_branch do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} -> {:ok, String.trim(branch)}
      {error, _} -> {:error, error}
    end
  end

  def sanitize_for_db(branch) do
    branch
    |> String.replace(~r/[^a-zA-Z0-9]/, "_")
    |> String.downcase()
  end

  def sanitize_for_hostname(branch) do
    branch
    |> String.replace(~r|/|, "-")
    |> String.replace(~r/[^a-zA-Z0-9-]/, "")
    |> String.downcase()
    |> String.slice(0, 63)  # DNS label max length
  end
end
```

#### IP Allocation

```elixir
defmodule DevIp.Allocator do
  use GenServer

  def get_or_allocate(branch) do
    GenServer.call(__MODULE__, {:get_or_allocate, branch})
  end

  @impl true
  def handle_call({:get_or_allocate, branch}, _from, state) do
    case Registry.find_by_branch(branch) do
      {:ok, allocation} ->
        Registry.update_heartbeat(branch)
        {:reply, {:ok, allocation}, state}

      :not_found ->
        case Registry.next_available_ip() do
          {:ok, ip} ->
            hostname = Git.sanitize_for_hostname(branch)
            allocation = %{
              branch: branch,
              ip: ip,
              hostname: hostname,
              pid: System.pid() |> String.to_integer(),
              project_path: File.cwd!(),
              allocated_at: DateTime.utc_now(),
              last_seen_at: DateTime.utc_now()
            }
            Registry.insert_allocation(allocation)
            {:reply, {:ok, allocation}, state}

          {:error, :pool_exhausted} ->
            {:reply, {:error, :no_available_ips}, state}
        end
    end
  end
end
```

#### mDNS Announcement

```elixir
defmodule DevIp.Mdns do
  use GenServer
  require Logger

  def start_link(opts) do
    hostname = Keyword.fetch!(opts, :hostname)
    ip = Keyword.fetch!(opts, :ip)
    port = Keyword.get(opts, :port, 4000)
    GenServer.start_link(__MODULE__, {hostname, ip, port}, name: __MODULE__)
  end

  @impl true
  def init({hostname, ip, port}) do
    case start_dns_sd(hostname, ip, port) do
      {:ok, port_ref} ->
        Logger.info("[DevIp] mDNS: #{hostname}.local -> #{ip}:#{port}")
        {:ok, %{port: port_ref, hostname: hostname}}

      {:error, reason} ->
        Logger.warning("[DevIp] mDNS failed: #{reason}")
        {:ok, %{port: nil, hostname: hostname}}
    end
  end

  @impl true
  def terminate(_reason, %{port: port}) when is_port(port) do
    # Get OS PID and kill dns-sd
    case :erlang.port_info(port, :os_pid) do
      {:os_pid, os_pid} ->
        System.cmd("kill", [to_string(os_pid)], stderr_to_stdout: true)
      _ ->
        :ok
    end
  end
  def terminate(_, _), do: :ok

  defp start_dns_sd(hostname, ip, port) do
    args = [
      "-P",
      hostname,
      "_http._tcp",
      "local",
      to_string(port),
      "#{hostname}.local",
      ip
    ]

    dns_sd = System.find_executable("dns-sd") || "/usr/bin/dns-sd"

    try do
      port_ref = Port.open({:spawn_executable, dns_sd}, [
        :binary,
        :exit_status,
        args: args
      ])
      {:ok, port_ref}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end
end
```

#### Phoenix Integration

```elixir
defmodule DevIp.Phoenix do
  require Logger

  def configure!(app, endpoint) when is_atom(app) and is_atom(endpoint) do
    with {:ok, branch} <- DevIp.Git.current_branch(),
         {:ok, allocation} <- DevIp.get_or_allocate(branch) do

      ip_tuple = parse_ip(allocation.ip)

      # Configure Repo (database per branch)
      db_name = "#{app}_dev_#{DevIp.Git.sanitize_for_db(branch)}"
      configure_repo(app, db_name)

      # Configure Endpoint
      Application.put_env(app, endpoint,
        Keyword.merge(
          Application.get_env(app, endpoint, []),
          http: [ip: ip_tuple, port: allocation.port],
          url: [host: "#{allocation.hostname}.local", port: allocation.port],
          check_origin: false
        )
      )

      # Store for mDNS (started in Application)
      Application.put_env(:dev_ip, :current_allocation, allocation)

      Logger.info("""

      ════════════════════════════════════════════════════════════════
        DevIp Configuration
      ────────────────────────────────────────────────────────────────
        Branch:   #{branch}
        IP:       #{allocation.ip}
        Database: #{db_name}
        URL:      http://#{allocation.hostname}.local:#{allocation.port}
      ════════════════════════════════════════════════════════════════
      """)

      :ok
    else
      {:error, reason} ->
        Logger.error("[DevIp] Configuration failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_ip(ip_string) do
    ip_string
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()
  end

  defp configure_repo(app, db_name) do
    repo = Module.concat([Macro.camelize(to_string(app)), "Repo"])
    if Code.ensure_loaded?(repo) do
      current = Application.get_env(app, repo, [])
      Application.put_env(app, repo, Keyword.put(current, :database, db_name))
    end
  end
end
```

### Prerequisites

The Elixir package assumes:
1. Loopback aliases pre-created (via nix-darwin)
2. PF hairpin rules pre-configured (via nix-darwin)
3. `dns-sd` available (macOS built-in)

---

## Option B: Go/Rust Daemon

### Why Go?

- puma-dev is Go, proven model
- Good for daemons, low memory
- Easy cross-platform compilation
- Good networking primitives

### Why Rust?

- No runtime, tiny binary
- Excellent for systems programming
- Growing ecosystem

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         dev-ip daemon                           │
│                    (runs as root/privileged)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ HTTP API    │  │ DNS Server  │  │ Loopback Manager        │ │
│  │ :9876       │  │ :5354       │  │ - ifconfig lo0 alias    │ │
│  │             │  │ .test TLD   │  │ - PF NAT rules          │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Registry (SQLite)                                           ││
│  │ ~/.local/share/dev-ip/registry.db                           ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Optional: Reverse Proxy + Auto HTTPS                       ││
│  │ - mkcert integration                                        ││
│  │ - Proxy to allocated IPs                                    ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### CLI Interface

```bash
# Installation
brew install dev-ip
# or
cargo install dev-ip

# Setup (creates launchd plist, runs daemon)
sudo dev-ip install

# In a project directory:
dev-ip up
# → Detects project type (Phoenix, Rails, Node, etc.)
# → Allocates IP
# → Creates loopback alias if needed
# → Starts DNS for project-name.test
# → Optionally starts the app

# Or just register without starting:
dev-ip register my-feature
# → Returns: 127.0.0.23

# List allocations
dev-ip list
# BRANCH              IP              PORT    URL
# main                127.0.0.10      4000    main.test
# ijcd/auth-feature   127.0.0.23      4000    auth-feature.test

# Release
dev-ip release my-feature

# Status
dev-ip status
```

### HTTP API

```
GET  /allocations           # List all
POST /allocations           # Create: {branch, port, project_path}
GET  /allocations/:branch   # Get one
DELETE /allocations/:branch # Release

GET  /config                # Get config
PUT  /config                # Update config

POST /loopback/:ip          # Ensure loopback alias exists
DELETE /loopback/:ip        # Remove loopback alias (if no allocations)

GET  /health                # Health check
```

### DNS Server

Built-in DNS server for .test domains:

```
┌─────────────────────────────────────────────────────────────────┐
│ Query: auth-feature.test                                        │
│                    ↓                                            │
│ /etc/resolver/test → nameserver 127.0.0.1 port 5354            │
│                    ↓                                            │
│ dev-ip DNS server                                               │
│                    ↓                                            │
│ Lookup in registry: auth-feature → 127.0.0.23                  │
│                    ↓                                            │
│ Response: A 127.0.0.23                                          │
└─────────────────────────────────────────────────────────────────┘
```

### Loopback Management

```go
// Pseudocode
func ensureLoopbackAlias(ip string) error {
    // Check if alias exists
    if aliasExists(ip) {
        return nil
    }

    // Create alias (requires root)
    cmd := exec.Command("ifconfig", "lo0", "alias", ip)
    return cmd.Run()
}

func ensurePfRule(ip string) error {
    // Add NAT rule for hairpin routing
    rule := fmt.Sprintf("nat on lo0 from %s to %s -> 127.0.0.1", ip, ip)
    // Add to anchor, reload PF
    return addPfAnchorRule(rule)
}
```

### Project Detection

```go
type ProjectType string

const (
    Phoenix ProjectType = "phoenix"
    Rails   ProjectType = "rails"
    Node    ProjectType = "node"
    Go      ProjectType = "go"
    Generic ProjectType = "generic"
)

func detectProject(path string) ProjectType {
    if fileExists(path, "mix.exs") {
        return Phoenix
    }
    if fileExists(path, "Gemfile") && fileExists(path, "config/routes.rb") {
        return Rails
    }
    if fileExists(path, "package.json") {
        return Node
    }
    if fileExists(path, "go.mod") {
        return Go
    }
    return Generic
}
```

### Language Integrations

Thin wrappers that call the CLI or HTTP API:

#### Elixir

```elixir
defmodule DevIp do
  def get_allocation do
    {json, 0} = System.cmd("dev-ip", ["info", "--json"])
    Jason.decode!(json)
  end

  def configure_phoenix!(app, endpoint) do
    case get_allocation() do
      %{"ip" => ip, "hostname" => hostname, "port" => port} ->
        # Configure endpoint...
      nil ->
        # Auto-register
        {json, 0} = System.cmd("dev-ip", ["register", "--json"])
        # ...
    end
  end
end
```

#### Ruby

```ruby
# dev-ip-rails gem
module DevIp
  def self.configure!
    allocation = JSON.parse(`dev-ip info --json`)
    # Configure Rails...
  end
end
```

### Installation (macOS)

```bash
# Install binary
brew install dev-ip

# Setup daemon and resolver
sudo dev-ip install
# → Creates /Library/LaunchDaemons/com.dev-ip.daemon.plist
# → Creates /etc/resolver/test
# → Starts daemon
```

### Launchd Plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dev-ip.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/dev-ip</string>
        <string>daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/dev-ip.log</string>
</dict>
</plist>
```

---

## Comparison

| Feature | Elixir Hex | Go/Rust Daemon |
|---------|------------|----------------|
| Setup complexity | Low (add dep) | Medium (install daemon) |
| Privileged ops | External (nix) | Built-in |
| Language support | Phoenix only | Any |
| DNS | mDNS (.local) | Real DNS (.test) |
| HTTPS | No | Yes (mkcert) |
| Auto-start apps | No | Optional |
| Resource usage | Per-app | Single daemon |
| Maintenance | Per-project | System-wide |

## Recommendation

**Start with Elixir Hex package** for immediate Phoenix use.

**Build Go daemon later** for:
- Multi-language support
- Simpler setup (no nix prereqs)
- Real DNS instead of mDNS
- HTTPS certificates

The Hex package can later become a thin wrapper around the daemon's HTTP API, maintaining API compatibility.

---

## Next Steps

1. [ ] Build `dev_ip` Hex package (MVP)
2. [ ] Test with Phoenix project + worktrees
3. [ ] Document nix-darwin prerequisites
4. [ ] Evaluate Go vs Rust for daemon
5. [ ] Design daemon HTTP API
6. [ ] Build daemon MVP
7. [ ] Create language wrappers

---

## Future Vision: Full Service Coordinator (`dev-env`)

### Concept

Expand from IP allocation to full local development orchestration - like docker-compose but native, with IP isolation. Coordinates all services (Postgres, Redis, Elasticsearch, app) for a project/branch.

```
┌─────────────────────────────────────────────────────────────────┐
│                      dev-env daemon                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Environment: ijcd/auth-feature                                 │
│  IP: 127.0.0.23                                                 │
│                                                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │ Postgres    │ │ Redis       │ │ Elasticsearch│ │ Phoenix   │ │
│  │ :5432       │ │ :6379       │ │ :9200        │ │ :4000     │ │
│  │ pg.auth-    │ │ redis.auth- │ │ es.auth-     │ │ auth-     │ │
│  │ feature.test│ │ feature.test│ │ feature.test │ │ feature.  │ │
│  │             │ │             │ │              │ │ test      │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │
│        ↓               ↓               ↓              ↓         │
│   All bound to 127.0.0.23, all announced via DNS                │
└─────────────────────────────────────────────────────────────────┘
```

### Project Config: `dev-env.toml`

```toml
[environment]
name = "myapp"  # Optional, defaults to git branch

[services.postgres]
enabled = true
version = "16"
port = 5432
database = "${ENV_NAME}_dev"  # myapp_auth_feature_dev

[services.redis]
enabled = true
port = 6379

[services.elasticsearch]
enabled = false  # Only enable when needed
version = "8"
port = 9200

[services.app]
type = "phoenix"  # or "rails", "node", "go", "custom"
port = 4000
command = "mix phx.server"  # Optional override
env = { MIX_ENV = "dev" }

[dns]
domain = "test"  # .test TLD
# Generates:
#   myapp-auth-feature.test       → 127.0.0.23:4000 (app)
#   pg.myapp-auth-feature.test    → 127.0.0.23:5432
#   redis.myapp-auth-feature.test → 127.0.0.23:6379
```

### CLI

```bash
# Start everything for this branch
dev-env up
# → Allocates IP 127.0.0.23
# → Starts Postgres on 127.0.0.23:5432
# → Starts Redis on 127.0.0.23:6379
# → Creates database myapp_auth_feature_dev
# → Runs migrations
# → Starts Phoenix on 127.0.0.23:4000
# → Announces all services via DNS

# Status
dev-env status
# ENVIRONMENT: myapp/ijcd-auth-feature
# IP: 127.0.0.23
#
# SERVICE       STATUS    PORT   DNS
# postgres      running   5432   pg.auth-feature.test
# redis         running   6379   redis.auth-feature.test
# app           running   4000   auth-feature.test

# Stop everything
dev-env down

# Just start specific services
dev-env up postgres redis

# Connect to this environment's postgres
dev-env psql
# → Connects to 127.0.0.23:5432

# Logs
dev-env logs postgres
dev-env logs app

# List all environments
dev-env list
# ENVIRONMENT              IP              SERVICES          STATUS
# myapp/main               127.0.0.10      pg,redis,app      running
# myapp/auth-feature       127.0.0.23      pg,redis,app      running
# other-project/main       127.0.0.15      pg,app            stopped
```

### Data Isolation

```
~/.local/share/dev-env/
├── registry.db                      # SQLite: environments, allocations
├── environments/
│   ├── myapp-main/
│   │   ├── postgres/                # Postgres data dir
│   │   └── redis/                   # Redis dump
│   ├── myapp-auth-feature/
│   │   ├── postgres/
│   │   └── redis/
│   └── other-project-main/
│       └── postgres/
└── logs/
    ├── myapp-auth-feature-postgres.log
    ├── myapp-auth-feature-redis.log
    └── myapp-auth-feature-app.log
```

### Environment Variables Injected

```bash
# Set automatically when running app
DEV_ENV_NAME=auth-feature
DEV_ENV_IP=127.0.0.23
DATABASE_URL=postgres://127.0.0.23:5432/myapp_auth_feature_dev
REDIS_URL=redis://127.0.0.23:6379
ELASTICSEARCH_URL=http://127.0.0.23:9200

# Phoenix-specific
PHX_HOST=auth-feature.test
PHX_PORT=4000
```

### vs Docker Compose

| Aspect | dev-env | docker-compose |
|--------|---------|----------------|
| Startup time | Fast (native) | Slower (containers) |
| Resource usage | Low | Higher (per-container) |
| File access | Native speed | Volume mount overhead |
| Debugging | Normal tools | Container exec |
| IP isolation | Per-environment | Per-network |
| macOS overhead | None | Linux VM required |
| Service versions | System installed | Per-container |

### Built-in Services

```rust
enum Service {
    Postgres { version: String, extensions: Vec<String> },
    Redis,
    Elasticsearch { version: String },
    Memcached,
    Minio,  // S3-compatible
    Mailpit,  // Email testing
    Custom { command: String, health_check: Option<String> },
}
```

### Service Discovery for Apps

```elixir
# Phoenix app just reads env vars - no special library needed
config :my_app, MyApp.Repo,
  url: System.get_env("DATABASE_URL")

config :my_app, :redis,
  url: System.get_env("REDIS_URL")
```

This is essentially **"devenv + overmind + IP isolation + DNS + service coordination"** unified in one tool.
