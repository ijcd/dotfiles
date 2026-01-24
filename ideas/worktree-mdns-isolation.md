# Dynamic Worktree Isolation via mDNS

> **Note**: This was the initial exploration. See `smooth-worktree-workflow.md` for the
> recommended approach: shared Postgres + Phoenix auto-detection + mDNS announcement.

## Problem

Run multiple Claude instances in parallel, each in its own git worktree, with:
- Isolated hostnames per branch
- Different loopback IPs (127.0.0.x) per worktree
- No pre-configuration needed
- Auto-cleanup when dev server stops

## Solution: `dns-sd -P` (mDNS Proxy Registration)

macOS mDNS can announce arbitrary hostname → IP mappings:

```bash
dns-sd -P "auth-feature" _http._tcp local 4000 auth-feature.local 127.0.0.11
```

This makes `auth-feature.local` resolve to `127.0.0.11` - verified working.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│ Phoenix server starts in worktree                               │
│ Branch: ijcd/auth-feature                                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────────┐
                    │ dns-sd -P announces │
                    │ auth-feature.local  │
                    │ → 127.0.0.11        │
                    └─────────────────────┘
                              ↓
                    ┌─────────────────────┐
                    │ mDNSResponder       │
                    │ (macOS built-in)    │
                    └─────────────────────┘
                              ↓
         ┌────────────────────────────────────────┐
         │ ping/curl auth-feature.local works!   │
         │ Process dies → record disappears      │
         └────────────────────────────────────────┘
```

### Key Properties

| Property | Behavior |
|----------|----------|
| Announcement lifetime | Dies with `dns-sd` process |
| Cleanup needed | None - automatic |
| Infrastructure | Zero - uses macOS built-in mDNSResponder |
| Domain | `.local` (mDNS reserved) |
| Different IPs | Yes - each worktree gets unique 127.0.0.x |

## Implementation Sketch

### Wrapper Script: `wt-serve`

```bash
#!/bin/bash
# wt-serve - start Phoenix with mDNS announcement

set -e

BRANCH=$(git branch --show-current)
# Sanitize branch name for hostname (alphanumeric + hyphens only)
SERVICE_NAME=$(echo "$BRANCH" | sed 's|/|-|g; s/[^a-zA-Z0-9-]//g')

# Derive IP from branch name hash (deterministic, range .10-.99)
HASH=$(echo "$BRANCH" | md5 | cut -c1-2)
IP_SUFFIX=$((16#$HASH % 90 + 10))
IP="127.0.0.$IP_SUFFIX"

PORT=${DEV_PORT:-4000}

# Create loopback alias if needed
sudo ifconfig lo0 alias "$IP" 2>/dev/null || true

# Announce via mDNS (runs in background, dies with script)
dns-sd -P "$SERVICE_NAME" _http._tcp local "$PORT" "${SERVICE_NAME}.local" "$IP" &
DNS_SD_PID=$!
trap "kill $DNS_SD_PID 2>/dev/null" EXIT

echo "═══════════════════════════════════════════════════"
echo "Branch:   $BRANCH"
echo "Hostname: ${SERVICE_NAME}.local"
echo "IP:       $IP"
echo "URL:      http://${SERVICE_NAME}.local:${PORT}"
echo "═══════════════════════════════════════════════════"

# Start Phoenix bound to this IP
DEV_IP=$IP mix phx.server
```

### Phoenix dev.exs Changes

```elixir
# Read IP from environment, default to existing
dev_ip =
  case System.get_env("DEV_IP") do
    nil -> {127, 0, 0, 10}
    ip_str ->
      ip_str
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
      |> List.to_tuple()
  end

config :my_app, MyAppWeb.Endpoint,
  http: [ip: dev_ip, port: 4000],
  ...
```

## Comparison with Alternatives

| Approach | Different IPs | Zero Config | Domain | Cleanup |
|----------|--------------|-------------|--------|---------|
| **mDNS (this)** | Yes | Yes | `.local` | Automatic |
| dnsmasq dynamic | Yes | No | `.test` | Manual |
| dnsmasq static | Yes | No | `.test` | N/A |
| Port-only | No | Yes | N/A | N/A |

## Prerequisites

Already in place from `local-dev.nix`:
- PF NAT rules for hairpin routing (range 127.0.0.10-99)
- Loopback aliases (or add dynamically in script)

May need:
- Extend loopback alias range in nix config
- Or create aliases dynamically per-worktree (requires sudo)

## Open Questions

1. **Loopback aliases**: Pre-create range in nix, or sudo per-worktree?
2. **Port in URL**: Accept `:4000` suffix, or set up PF redirect 80→4000?
3. **Collision handling**: Hash collision possible (90 IPs) - add detection?
4. **devenv integration**: Put `wt-serve` in project's devenv.nix?

## Testing

```bash
# Terminal 1: Register manually
dns-sd -P "test-service" _http._tcp local 4000 test-service.local 127.0.0.11

# Terminal 2: Verify resolution
ping test-service.local
# Should show: PING test-service.local (127.0.0.11)

# Ctrl+C Terminal 1, then Terminal 2:
ping test-service.local
# Should fail - record gone
```
