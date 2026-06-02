---
name: treehouse-firewall-debug
description: Debug ERR_EMPTY_RESPONSE / connection reset on Treehouse loopback aliases (127.0.0.x). Covers the full stack - loopback aliases, pf hairpin NAT, dns-sd mDNS, macOS Application Firewall, nix binary codesigning.
---

# Treehouse + macOS Networking Debugging

When a dev server returns ERR_EMPTY_RESPONSE, connection reset, or empty replies on a Treehouse loopback alias IP, follow this diagnostic flow through all 5 layers.

## Background: The Full Stack

Treehouse uses per-branch loopback IPs for isolated dev environments. The networking stack has 5 layers, ALL of which must be working:

| Layer | What | Managed by | Check command |
|-------|------|-----------|---------------|
| 1. Loopback aliases | `ifconfig lo0 alias 127.0.0.X` (.10-.99) | nix-darwin | `ifconfig lo0 \| grep "inet 127.0.0"` |
| 2. Hairpin NAT | `nat on lo0 from X to X -> 127.0.0.1` | nix-darwin (`/etc/pf.anchors/loopback_dev`) | `sudo pfctl -a loopback_dev -s nat` |
| 3. pf enabled | Packet filter must be running | nix-darwin | `sudo pfctl -s info` (Status: Enabled) |
| 4. mDNS | `dns-sd -P` maps `branch.project.local` → IP | Treehouse | `dns-sd -G v4 <hostname>` |
| 5. App Firewall | `socketfilterfw` blocks unsigned binaries | **Nothing** (gap!) | `codesign -v <binary>` |

Layer 5 is the most common failure on macOS Sequoia 15.4+.

## Diagnostic Steps (check all layers in order)

### Layer 1: Loopback aliases

```bash
ifconfig lo0 | grep "inet 127.0.0"
# Should show 127.0.0.1 plus .10-.99 aliases
# If missing: nix-darwin config issue, or machine rebooted and aliases not re-applied
```

### Layer 2: Hairpin NAT rules

```bash
cat /etc/pf.anchors/loopback_dev | head -5
# Should show: nat on lo0 from 127.0.0.10 to 127.0.0.10 -> 127.0.0.1
# If file missing: nix-darwin not configured for loopback_dev anchor

sudo pfctl -a loopback_dev -s nat | head -5
# Should show loaded NAT rules
# If empty: anchor exists but isn't loaded
```

### Layer 3: pf enabled

```bash
sudo pfctl -s info 2>&1 | head -3
# Should show: Status: Enabled
# If disabled: sudo pfctl -E
```

### Layer 4: mDNS resolution

```bash
# Check if hostname resolves to the expected IP
dns-sd -G v4 <branch>.<project>.local
# e.g.: dns-sd -G v4 ijcd-evernote-elixir-thrift.gracenote.local
# Should show: <hostname> 127.0.0.17 (or whatever IP was allocated)
# Kill with Ctrl+C after result appears

# If not resolving: is the Treehouse dns-sd process running?
ps aux | grep dns-sd | grep -v grep
```

### Layer 5: Application Firewall + Binary Codesigning

This is the most common failure. macOS Sequoia 15.4+ Application Firewall silently blocks unsigned binaries from responding on any non-127.0.0.1 loopback alias. No logs, no errors — just empty responses.

```bash
# 5a. Check if the server binary is signed
BEAM=$(echo $(dirname $(which erl))/../lib/erlang/erts-*/bin/beam.smp)
codesign -v "$BEAM" 2>&1
# "valid on disk" = signed (good)
# "code object is not signed at all" = NEEDS SIGNING

# 5b. Check firewall state
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
# Should be enabled

# 5c. Check if binary is explicitly blocked
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps | grep -i beam
# "BLOCK" = user clicked "No" on firewall popup → needs --unblockapp
```

#### Confirm it's the firewall (not your app)

```bash
# Test with a system-signed binary on the SAME IP
IP=127.0.0.17  # replace with your treehouse IP
echo "hello" | nc -l $IP 8888 &
curl http://$IP:8888
# If nc works → it's not the network stack, it's the binary signing

# Test with another unsigned binary
python3 -c "
import http.server, socketserver
handler = http.server.SimpleHTTPRequestHandler
with socketserver.TCPServer(('$IP', 9999), handler) as s: s.serve_forever()
" &
curl http://$IP:9999
# If this ALSO fails → confirmed: firewall blocks unsigned binaries on aliases
```

## Fixes

### Fix: Sign beam.smp (most common fix)

```bash
# If project has devenv.nix with sign-beam script:
devenv script sign-beam

# Manual fix:
BEAM=$(echo $(dirname $(which erl))/../lib/erlang/erts-*/bin/beam.smp)
sudo cp "$BEAM" "$BEAM.bak"
sudo cp "$BEAM.bak" "$BEAM.tmp"
sudo codesign -s - -f "$BEAM.tmp"
sudo mv "$BEAM.tmp" "$BEAM"
sudo rm "$BEAM.bak"
```

### Fix: User accidentally denied firewall popup

```bash
BEAM=$(echo $(dirname $(which erl))/../lib/erlang/erts-*/bin/beam.smp)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$BEAM"
```

### Fix: Missing loopback aliases

```bash
# Re-apply via nix-darwin rebuild, or manually:
for i in $(seq 10 99); do sudo ifconfig lo0 alias 127.0.0.$i up; done
```

### Fix: pf/NAT not loaded

```bash
sudo pfctl -E  # enable pf
sudo pfctl -f /etc/pf.conf  # reload rules including loopback_dev anchor
```

## Key Facts

- `socketfilterfw` is the macOS Application Firewall — separate from `pf` (packet filter)
- Disabling pf won't fix firewall issues; disabling socketfilterfw won't fix pf issues
- The Application Firewall produces NO logs for blocked loopback traffic
- 127.0.0.1 is always exempt from Application Firewall checks
- Any non-127.0.0.1 loopback alias is subject to unsigned binary blocking (Sequoia 15.4+)
- Each nix store rebuild = new binary path = needs re-signing
- `--add` alone doesn't work for unsigned binaries — must `codesign` FIRST, then `--add`/`--unblockapp`
- The hairpin NAT (`loopback_dev` anchor) rewrites source IP so responses route correctly on lo0

## Anti-Patterns

- Don't disable the firewall globally — fix the specific binary
- Don't chase pf rules when the symptom is empty response from unsigned binary — check codesigning first
- Don't look for error logs — macOS doesn't log Application Firewall blocks on loopback
- Don't assume it's your app code — test a simple server on the same IP first
- Don't confuse `pf` (packet filter, Layer 2-3) with `socketfilterfw` (Application Firewall, Layer 5)
