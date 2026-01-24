# Smooth Worktree Workflow

## Goal

```bash
cd .worktrees/feature-branch
mix dev.server
# → Detects branch automatically
# → Creates DB if needed
# → Runs migrations
# → Announces via mDNS
# → http://feature-branch.local:4000 just works
```

Zero manual configuration per worktree.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ System Level (nix-darwin)                                       │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ PostgreSQL (shared)                                         │ │
│ │ localhost:5432                                              │ │
│ │ ├── myapp_dev_main                                          │ │
│ │ ├── myapp_dev_ijcd_auth_feature                             │ │
│ │ └── myapp_dev_ijcd_menu_work                                │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              ↑
          ┌───────────────────┼───────────────────┐
          ↓                   ↓                   ↓
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Main Worktree   │ │ Worktree 1      │ │ Worktree 2      │
│ branch: main    │ │ branch: ijcd/   │ │ branch: ijcd/   │
│                 │ │   auth-feature  │ │   menu-work     │
│ Phoenix :4000   │ │ Phoenix :4000   │ │ Phoenix :4000   │
│ main.local      │ │ auth-feature.   │ │ menu-work.local │
│                 │ │   local         │ │                 │
└─────────────────┘ └─────────────────┘ └─────────────────┘
          ↓                   ↓                   ↓
     mDNS announce       mDNS announce       mDNS announce
     (dies with app)     (dies with app)     (dies with app)
```

## Components

### 1. Shared PostgreSQL (nix-darwin)

Already configured in `~/.config/nix/darwin/postgres.nix`:
- Runs on localhost:5432
- Logs include database name for filtering
- Commands: `pg-start`, `pg-stop`, `pg-log-db <name>`

### 2. Phoenix Branch Detection

Add to `config/runtime.exs`:

```elixir
if config_env() == :dev do
  # ═══════════════════════════════════════════════════════════════
  # Auto-detect git branch and configure accordingly
  # ═══════════════════════════════════════════════════════════════

  branch_raw =
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} -> String.trim(branch)
      _ -> "main"
    end

  # Sanitize for database/hostname use
  branch_prefix =
    branch_raw
    |> String.replace(~r/[^a-zA-Z0-9]/, "_")
    |> String.downcase()

  # Sanitize for mDNS hostname (alphanumeric + hyphens only)
  branch_hostname =
    branch_raw
    |> String.replace(~r|/|, "-")
    |> String.replace(~r/[^a-zA-Z0-9-]/, "")
    |> String.downcase()

  database = "myapp_dev_#{branch_prefix}"

  # Database config
  config :my_app, MyApp.Repo,
    database: database,
    hostname: "localhost",
    port: 5432,
    pool_size: 10

  # Endpoint config (optional - for mDNS hostnames)
  config :my_app, MyAppWeb.Endpoint,
    url: [host: "#{branch_hostname}.local", port: 4000],
    check_origin: false  # Allow any origin in dev

  # Store for use by mDNS announcer
  Application.put_env(:my_app, :branch_hostname, branch_hostname)
  Application.put_env(:my_app, :branch_prefix, branch_prefix)

  IO.puts("""

  ═══════════════════════════════════════════════════════════════
    Branch:   #{branch_raw}
    Database: #{database}
    URL:      http://#{branch_hostname}.local:4000
  ═══════════════════════════════════════════════════════════════
  """)
end
```

### 3. mDNS Announcement (dies with app)

Create `lib/my_app/mdns_announcer.ex`:

```elixir
defmodule MyApp.MdnsAnnouncer do
  @moduledoc """
  Announces this Phoenix instance via mDNS using dns-sd.
  The announcement dies when the app stops - no cleanup needed.

  Only runs in dev environment.
  """
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    if Application.get_env(:my_app, :env) == :dev do
      hostname = Application.get_env(:my_app, :branch_hostname, "dev")
      port = Application.get_env(:my_app, MyAppWeb.Endpoint)[:http][:port] || 4000

      case announce(hostname, port) do
        {:ok, pid} ->
          Logger.info("mDNS: Announcing as #{hostname}.local:#{port}")
          {:ok, %{dns_sd_pid: pid, hostname: hostname}}

        {:error, reason} ->
          Logger.warning("mDNS: Failed to announce - #{reason}")
          {:ok, %{dns_sd_pid: nil, hostname: hostname}}
      end
    else
      :ignore
    end
  end

  @impl true
  def terminate(_reason, %{dns_sd_pid: pid}) when is_port(pid) do
    # Kill dns-sd process when app stops
    System.cmd("kill", ["-9", "#{:erlang.port_info(pid)[:os_pid]}"], stderr_to_stdout: true)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp announce(hostname, port) do
    # dns-sd -R <name> <type> <domain> <port>
    # This registers the service AND makes hostname.local resolvable
    args = [
      "-P",                           # Proxy registration
      hostname,                       # Service name
      "_http._tcp",                   # Service type
      "local",                        # Domain
      to_string(port),                # Port
      "#{hostname}.local",            # Hostname to register
      "127.0.0.1"                     # IP to resolve to
    ]

    try do
      port = Port.open({:spawn_executable, dns_sd_path()}, [
        :binary,
        :exit_status,
        args: args
      ])
      {:ok, port}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp dns_sd_path do
    System.find_executable("dns-sd") || "/usr/bin/dns-sd"
  end
end
```

Add to supervision tree in `lib/my_app/application.ex`:

```elixir
def start(_type, _args) do
  children = [
    # ... other children ...
    MyApp.Repo,
    MyAppWeb.Endpoint,
    # Add mDNS announcer (only starts in dev)
    MyApp.MdnsAnnouncer
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 4. Auto-Create Database Mix Task

Create `lib/mix/tasks/dev.server.ex`:

```elixir
defmodule Mix.Tasks.Dev.Server do
  @moduledoc """
  Starts the development server with automatic DB setup.

  Usage: mix dev.server

  This task:
  1. Creates the database if it doesn't exist
  2. Runs any pending migrations
  3. Starts the Phoenix server
  """
  use Mix.Task

  @shortdoc "Start dev server with auto DB setup"

  def run(_args) do
    # Create DB (quiet, no error if exists)
    Mix.Task.run("ecto.create", ["--quiet"])

    # Run migrations
    Mix.Task.run("ecto.migrate", ["--quiet"])

    # Start Phoenix
    Mix.Task.run("phx.server")
  end
end
```

## Usage

### Initial Setup (once)

```bash
# Apply nix-darwin config with shared postgres
darwin-rebuild switch --flake ~/.config/nix#<hostname>

# Verify postgres is running
pg-status
```

### Per-Project Setup (once)

Add the files above to your Phoenix project:
- Modify `config/runtime.exs`
- Add `lib/my_app/mdns_announcer.ex`
- Add `lib/mix/tasks/dev.server.ex`
- Update `lib/my_app/application.ex`

### Daily Workflow

```bash
# Main checkout
cd ~/work/project
mix dev.server
# → http://main.local:4000

# Create worktree for feature
git worktree add .worktrees/auth-feature -b ijcd/auth-feature
cd .worktrees/auth-feature

# Just works
mix dev.server
# → Creates DB: myapp_dev_ijcd_auth_feature
# → Runs migrations
# → Announces: auth-feature.local
# → http://ijcd-auth-feature.local:4000
```

### Monitoring

```bash
# Watch logs for your branch's database
pg-log-db ijcd_auth_feature

# Or from within the worktree
pg-log-db $(git branch --show-current | sed 's/[^a-zA-Z0-9]/_/g')
```

## Port Conflicts

If running multiple worktrees simultaneously, they'll conflict on port 4000.

Options:

### Option A: Different ports per worktree

```elixir
# In runtime.exs - hash branch to port
port = 4000 + :erlang.phash2(branch_prefix, 100)

config :my_app, MyAppWeb.Endpoint,
  http: [port: port],
  url: [host: "#{branch_hostname}.local", port: port]
```

### Option B: Per-worktree .env override

```bash
# .worktrees/auth-feature/.env
PORT=4001
```

```elixir
# runtime.exs
port = String.to_integer(System.get_env("PORT", "4000"))
```

### Option C: Only run one at a time

For most workflows, you only need one dev server. The mDNS names just give you nice URLs.

## Cleanup

```bash
# Remove worktree
cd ~/work/project
git worktree remove .worktrees/auth-feature

# Optionally drop the database
dropdb myapp_dev_ijcd_auth_feature
```

mDNS announcement dies automatically when the server stops - no cleanup needed.

## Troubleshooting

### mDNS not resolving

```bash
# Check if dns-sd is working
dns-sd -P "test" _http._tcp local 8080 test.local 127.0.0.1
# In another terminal:
ping test.local
```

### Database not found

```bash
# List all databases
psql -l | grep myapp

# Manually create
createdb myapp_dev_my_branch
```

### Port already in use

```bash
# Find what's using it
lsof -i :4000

# Kill it
kill -9 <pid>
```
