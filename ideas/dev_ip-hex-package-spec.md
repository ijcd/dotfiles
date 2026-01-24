# Spec: `dev_ip` Hex Package

## Overview

Build an Elixir Hex package called `dev_ip` that manages local development IP allocation for Phoenix projects. It enables running multiple worktrees/branches simultaneously, each on its own loopback IP (127.0.0.20-39), with automatic mDNS hostname announcement.

## Prerequisites (Assumed External Setup)

- Loopback aliases pre-created: `ifconfig lo0 alias 127.0.0.x` for range 10-99
- PF hairpin NAT rules configured
- macOS with `dns-sd` command available (built-in)
- Shared PostgreSQL running on localhost:5432

## Core Features

1. **IP Allocation**: Assign unique IPs from 127.0.0.20-39 pool per branch
2. **Registry**: SQLite database tracking allocations
3. **mDNS Announcement**: Use `dns-sd -P` to announce `branch-name.local`
4. **Phoenix Integration**: One-line configuration in runtime.exs
5. **Stale Cleanup**: Heartbeat mechanism to detect dead allocations

## Package Structure

```
dev_ip/
├── lib/
│   ├── dev_ip.ex                    # Main API
│   ├── dev_ip/
│   │   ├── application.ex           # OTP Application
│   │   ├── git.ex                   # Git branch detection
│   │   ├── registry.ex              # SQLite storage
│   │   ├── allocator.ex             # IP allocation GenServer
│   │   ├── mdns.ex                  # mDNS announcement GenServer
│   │   ├── heartbeat.ex             # Heartbeat GenServer
│   │   └── phoenix.ex               # Phoenix integration
│   └── mix/tasks/
│       ├── dev_ip.list.ex           # mix dev_ip.list
│       ├── dev_ip.info.ex           # mix dev_ip.info
│       ├── dev_ip.release.ex        # mix dev_ip.release <branch>
│       └── dev_ip.cleanup.ex        # mix dev_ip.cleanup
├── mix.exs
├── README.md
├── .formatter.exs
└── test/
    ├── test_helper.exs
    ├── dev_ip_test.exs
    ├── dev_ip/
    │   ├── git_test.exs
    │   ├── registry_test.exs
    │   └── allocator_test.exs
    └── support/
```

## Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:exqlite, "~> 0.23"},
    {:ex_doc, "~> 0.31", only: :dev, runtime: false}
  ]
end
```

## Configuration

```elixir
# config/config.exs (in consuming app)
config :dev_ip,
  registry_path: "~/.local/share/dev_ip/registry.db",
  ip_range_start: 20,
  ip_range_end: 39,
  stale_threshold_minutes: 30,
  domain: "local",  # .local for mDNS
  default_port: 4000
```

## Module Specifications

### `DevIp` (Main API)

```elixir
defmodule DevIp do
  @moduledoc """
  Local development IP allocation for Phoenix projects.

  Manages a pool of loopback IPs (127.0.0.20-39) and assigns
  unique IPs per git branch. Announces via mDNS so
  `branch-name.local` resolves to the allocated IP.
  """

  @type allocation :: %{
    branch: String.t(),
    ip: String.t(),
    hostname: String.t(),
    port: integer(),
    pid: integer(),
    project_path: String.t(),
    allocated_at: DateTime.t(),
    last_seen_at: DateTime.t()
  }

  @doc "Allocate an IP for the given branch"
  @spec allocate(String.t()) :: {:ok, allocation()} | {:error, term()}
  def allocate(branch)

  @doc "Get existing allocation or allocate new"
  @spec get_or_allocate(String.t()) :: {:ok, allocation()} | {:error, term()}
  def get_or_allocate(branch)

  @doc "Release allocation for branch"
  @spec release(String.t()) :: :ok | {:error, :not_found}
  def release(branch)

  @doc "List all allocations"
  @spec list() :: [allocation()]
  def list()

  @doc "Get allocation for branch"
  @spec info(String.t()) :: allocation() | nil
  def info(branch)

  @doc "Cleanup stale allocations (no heartbeat in threshold)"
  @spec cleanup_stale() :: {:ok, integer()}
  def cleanup_stale()
end
```

### `DevIp.Git`

```elixir
defmodule DevIp.Git do
  @moduledoc "Git branch detection and name sanitization"

  @doc "Get current git branch name"
  @spec current_branch() :: {:ok, String.t()} | {:error, String.t()}
  def current_branch do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} -> {:ok, String.trim(branch)}
      {error, _} -> {:error, String.trim(error)}
    end
  end

  @doc "Sanitize branch name for database naming (alphanumeric + underscore)"
  @spec sanitize_for_db(String.t()) :: String.t()
  def sanitize_for_db(branch) do
    branch
    |> String.replace(~r/[^a-zA-Z0-9]/, "_")
    |> String.downcase()
  end

  @doc "Sanitize branch name for DNS hostname (alphanumeric + hyphen, max 63 chars)"
  @spec sanitize_for_hostname(String.t()) :: String.t()
  def sanitize_for_hostname(branch) do
    branch
    |> String.replace(~r|/|, "-")
    |> String.replace(~r/[^a-zA-Z0-9-]/, "")
    |> String.downcase()
    |> String.slice(0, 63)
  end
end
```

### `DevIp.Registry`

```elixir
defmodule DevIp.Registry do
  @moduledoc """
  SQLite-based registry for IP allocations.

  Database location: ~/.local/share/dev_ip/registry.db
  """

  @doc "Initialize database and tables"
  @spec init() :: :ok
  def init()

  @doc "Insert new allocation"
  @spec insert(map()) :: {:ok, map()} | {:error, term()}
  def insert(allocation)

  @doc "Find allocation by branch"
  @spec find_by_branch(String.t()) :: {:ok, map()} | :not_found
  def find_by_branch(branch)

  @doc "Find allocation by IP"
  @spec find_by_ip(String.t()) :: {:ok, map()} | :not_found
  def find_by_ip(ip)

  @doc "Get next available IP from pool"
  @spec next_available_ip() :: {:ok, String.t()} | {:error, :pool_exhausted}
  def next_available_ip()

  @doc "Delete allocation by branch"
  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(branch)

  @doc "List all allocations"
  @spec list_all() :: [map()]
  def list_all()

  @doc "Update heartbeat timestamp"
  @spec update_heartbeat(String.t()) :: :ok
  def update_heartbeat(branch)

  @doc "Delete allocations with no heartbeat in threshold"
  @spec delete_stale(integer()) :: {:ok, integer()}
  def delete_stale(threshold_minutes)
end
```

**SQLite Schema:**

```sql
CREATE TABLE IF NOT EXISTS allocations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  branch TEXT UNIQUE NOT NULL,
  ip TEXT UNIQUE NOT NULL,
  hostname TEXT NOT NULL,
  port INTEGER DEFAULT 4000,
  pid INTEGER,
  project_path TEXT,
  allocated_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_allocations_branch ON allocations(branch);
CREATE INDEX IF NOT EXISTS idx_allocations_ip ON allocations(ip);
CREATE INDEX IF NOT EXISTS idx_allocations_last_seen ON allocations(last_seen_at);
```

### `DevIp.Allocator`

```elixir
defmodule DevIp.Allocator do
  @moduledoc """
  GenServer managing IP allocations.
  Serializes allocation requests to prevent race conditions.
  """
  use GenServer

  def start_link(opts \\ [])
  def get_or_allocate(branch)
  def release(branch)
  def list()
  def info(branch)
end
```

### `DevIp.Mdns`

```elixir
defmodule DevIp.Mdns do
  @moduledoc """
  mDNS announcement via macOS dns-sd command.

  Runs `dns-sd -P` to announce hostname.local → IP.
  Process dies when GenServer stops, announcement disappears.
  """
  use GenServer

  @doc "Start announcer for given hostname/ip/port"
  def start_link(opts)
  # opts: [hostname: "my-branch", ip: "127.0.0.23", port: 4000]

  # Implementation spawns:
  # dns-sd -P "my-branch" _http._tcp local 4000 my-branch.local 127.0.0.23
end
```

### `DevIp.Heartbeat`

```elixir
defmodule DevIp.Heartbeat do
  @moduledoc """
  Periodic heartbeat to keep allocation alive.
  Updates last_seen_at every 60 seconds.
  """
  use GenServer

  def start_link(opts)
  # opts: [branch: "my-branch", interval: 60_000]
end
```

### `DevIp.Phoenix`

```elixir
defmodule DevIp.Phoenix do
  @moduledoc """
  One-line Phoenix integration.

  Usage in config/runtime.exs:

      if config_env() == :dev do
        DevIp.Phoenix.configure!(:my_app, MyAppWeb.Endpoint)
      end
  """

  @doc """
  Configure Phoenix app with allocated IP.

  - Detects git branch
  - Allocates IP from pool
  - Configures Endpoint to bind to IP
  - Configures Repo with branch-specific database
  - Starts mDNS announcer
  - Starts heartbeat
  - Logs configuration summary
  """
  @spec configure!(atom(), module(), keyword()) :: :ok | {:error, term()}
  def configure!(app, endpoint, opts \\ [])
end
```

**Implementation:**

```elixir
defmodule DevIp.Phoenix do
  require Logger

  def configure!(app, endpoint, opts \\ []) do
    port = Keyword.get(opts, :port, 4000)

    with {:ok, branch} <- DevIp.Git.current_branch(),
         {:ok, allocation} <- DevIp.get_or_allocate(branch) do

      ip_tuple = parse_ip(allocation.ip)
      db_name = "#{app}_dev_#{DevIp.Git.sanitize_for_db(branch)}"

      # Configure Repo
      configure_repo(app, db_name)

      # Configure Endpoint
      Application.put_env(app, endpoint,
        Keyword.merge(
          Application.get_env(app, endpoint, []),
          http: [ip: ip_tuple, port: port],
          url: [host: "#{allocation.hostname}.local", port: port],
          check_origin: false
        )
      )

      # Start mDNS announcer (supervised by DevIp.Application)
      DevIp.Mdns.announce(allocation.hostname, allocation.ip, port)

      # Start heartbeat
      DevIp.Heartbeat.start(branch)

      Logger.info("""

      ════════════════════════════════════════════════════════════════
        DevIp Configuration
      ────────────────────────────────────────────────────────────────
        Branch:   #{branch}
        IP:       #{allocation.ip}
        Database: #{db_name}
        URL:      http://#{allocation.hostname}.local:#{port}
      ════════════════════════════════════════════════════════════════
      """)

      :ok
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

### `DevIp.Application`

```elixir
defmodule DevIp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Ensure registry directory exists
    registry_path = DevIp.Registry.path()
    File.mkdir_p!(Path.dirname(registry_path))

    # Initialize database
    DevIp.Registry.init()

    # Cleanup stale allocations on startup
    DevIp.cleanup_stale()

    children = [
      DevIp.Allocator,
      {DynamicSupervisor, name: DevIp.MdnsSupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: DevIp.HeartbeatSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: DevIp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Mix Tasks

### `mix dev_ip.list`

```elixir
defmodule Mix.Tasks.DevIp.List do
  use Mix.Task

  @shortdoc "List all IP allocations"

  def run(_args) do
    Application.ensure_all_started(:dev_ip)

    allocations = DevIp.list()

    if Enum.empty?(allocations) do
      Mix.shell().info("No allocations")
    else
      Mix.shell().info("BRANCH                          IP              PORT    URL")
      Mix.shell().info(String.duplicate("-", 80))

      for a <- allocations do
        Mix.shell().info(
          String.pad_trailing(a.branch, 32) <>
          String.pad_trailing(a.ip, 16) <>
          String.pad_trailing(to_string(a.port), 8) <>
          "#{a.hostname}.local"
        )
      end
    end
  end
end
```

### `mix dev_ip.info`

```elixir
defmodule Mix.Tasks.DevIp.Info do
  use Mix.Task

  @shortdoc "Show allocation for current branch"

  def run(_args) do
    Application.ensure_all_started(:dev_ip)

    case DevIp.Git.current_branch() do
      {:ok, branch} ->
        case DevIp.info(branch) do
          nil -> Mix.shell().info("No allocation for branch: #{branch}")
          a ->
            Mix.shell().info("""
            Branch:   #{a.branch}
            IP:       #{a.ip}
            Hostname: #{a.hostname}.local
            Port:     #{a.port}
            Path:     #{a.project_path}
            Since:    #{a.allocated_at}
            """)
        end

      {:error, reason} ->
        Mix.shell().error("Failed to detect branch: #{reason}")
    end
  end
end
```

### `mix dev_ip.release`

```elixir
defmodule Mix.Tasks.DevIp.Release do
  use Mix.Task

  @shortdoc "Release IP allocation for a branch"

  def run(args) do
    Application.ensure_all_started(:dev_ip)

    branch = case args do
      [b] -> b
      [] ->
        case DevIp.Git.current_branch() do
          {:ok, b} -> b
          {:error, _} ->
            Mix.shell().error("No branch specified and not in git repo")
            System.halt(1)
        end
    end

    case DevIp.release(branch) do
      :ok -> Mix.shell().info("Released: #{branch}")
      {:error, :not_found} -> Mix.shell().error("No allocation for: #{branch}")
    end
  end
end
```

### `mix dev_ip.cleanup`

```elixir
defmodule Mix.Tasks.DevIp.Cleanup do
  use Mix.Task

  @shortdoc "Clean up stale allocations"

  def run(_args) do
    Application.ensure_all_started(:dev_ip)

    case DevIp.cleanup_stale() do
      {:ok, 0} -> Mix.shell().info("No stale allocations")
      {:ok, n} -> Mix.shell().info("Cleaned up #{n} stale allocation(s)")
    end
  end
end
```

## Usage Example

### In Phoenix Project

```elixir
# mix.exs
defp deps do
  [
    {:dev_ip, path: "../dev_ip", only: :dev}
  ]
end
```

```elixir
# config/runtime.exs
if config_env() == :dev do
  DevIp.Phoenix.configure!(:my_app, MyAppWeb.Endpoint)
end
```

### Result

```bash
$ cd .worktrees/auth-feature
$ mix phx.server

════════════════════════════════════════════════════════════════
  DevIp Configuration
────────────────────────────────────────────────────────────────
  Branch:   ijcd/auth-feature
  IP:       127.0.0.23
  Database: my_app_dev_ijcd_auth_feature
  URL:      http://ijcd-auth-feature.local:4000
════════════════════════════════════════════════════════════════

[info] Running MyAppWeb.Endpoint with cowboy 2.10.0 at 127.0.0.23:4000 (http)
```

```bash
# In another terminal
$ curl http://ijcd-auth-feature.local:4000
# Works!

$ mix dev_ip.list
BRANCH                          IP              PORT    URL
--------------------------------------------------------------------------------
main                            127.0.0.10      4000    main.local
ijcd/auth-feature               127.0.0.23      4000    ijcd-auth-feature.local
```

## Testing Notes

- Mock `System.cmd` for git and dns-sd in tests
- Use separate test database path
- Test concurrent allocations
- Test stale cleanup logic

## Important Implementation Details

1. **Thread Safety**: Allocator GenServer serializes all allocation requests
2. **Cleanup on Start**: Remove stale allocations when app starts
3. **Heartbeat**: Update last_seen_at every 60s to prove liveness
4. **mDNS Process**: Spawn dns-sd as Port, kill on terminate
5. **IP Format**: Store as string "127.0.0.23", parse to tuple when needed
6. **Path Expansion**: Expand ~ in registry_path config

## What NOT to Include (Assumed External)

- Loopback alias creation (needs sudo, done via nix-darwin)
- PF NAT rules (done via nix-darwin)
- Postgres server (shared system postgres)
- Database creation (use `mix ecto.create` separately or add to dev.server task)