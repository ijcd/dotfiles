---
name: treehouse-firewall-debug
description: Debug Treehouse / per-branch loopback dev networking on macOS — hairpin routing, hairpin NAT, ERR_EMPTY_RESPONSE / "Empty reply from server" / connection reset on 127.0.0.x loopback aliases, broken after reboot, Phoenix returns nothing on a .local hostname. Covers all 5 layers: loopback aliases, pf hairpin NAT (loopback_dev anchor), pf enabled, dns-sd mDNS, macOS Application Firewall + nix binary codesigning.
---

# Treehouse + macOS Networking Debugging

When a dev server returns ERR_EMPTY_RESPONSE, connection reset, or "Empty reply from server" on a Treehouse loopback alias IP (`127.0.0.10–99`), follow this diagnostic flow through all 5 layers.

## Did the user say "after a reboot"?

If yes — **start at Layer 2** and explicitly ask for sudo to run the kernel-anchor check (see "Sudo discipline" below). The Layer 5 codesigning case (most-common cause normally) persists across reboots — so post-reboot it is almost never that. Post-reboot triage order is `2 → 3 → 1 → 4 → 5`, not `1 → 5`.

Specifically: the nix-darwin `pf-loopback` launchd daemon that loads `/etc/pf.anchors/loopback_dev` at boot suppresses stderr and has no retry. If anything goes wrong at boot (e.g. nix `/etc/static` not yet materialized when the daemon fires), the anchor file stays valid on disk but the kernel anchor is empty. `pf` is still enabled (Apple's own pfctl service runs independently), so `pfctl -s info` shows "Enabled" — but `pfctl -a loopback_dev -s nat` shows nothing. **One-line fix: `sudo pfctl -f /etc/pf.conf`.** Survives until next reboot.

## Sudo discipline

Layers 2 and 3 need sudo. **If sudo prompts for a password, ASK THE USER for it — do not skip these checks and jump to application-layer hypotheses (Phoenix crash, etc.).** Skipping cheap discriminating tests because of a password prompt is the failure mode that wastes the most time. The application layer almost never causes "Empty reply from server" on a stack with these symptoms.

## Background: The Full Stack

Treehouse uses per-branch loopback IPs for isolated dev environments. The networking stack has 5 layers, ALL of which must be working:

| Layer | What | Managed by | Check command |
|-------|------|-----------|---------------|
| 1. Loopback aliases | `ifconfig lo0 alias 127.0.0.X` (.10-.99) | nix-darwin | `ifconfig lo0 \| grep "inet 127.0.0"` |
| 2. Hairpin NAT in kernel | `nat on lo0 from X to X -> 127.0.0.1` LOADED into pf | nix-darwin (`/etc/pf.anchors/loopback_dev`) | `sudo pfctl -a loopback_dev -s nat` |
| 3. pf enabled | Packet filter must be running | nix-darwin | `sudo pfctl -s info` (Status: Enabled) |
| 4. mDNS | `dns-sd -P` maps `branch.project.local` → IP | Treehouse | `dns-sd -G v4 <hostname>` |
| 5. App Firewall | `socketfilterfw` blocks unsigned binaries | **Nothing** (gap!) | `codesign -v <binary>` |

**Common failure profiles:**
- **Fresh after reboot:** Layer 2 (kernel anchor empty though file exists). Fix: `sudo pfctl -f /etc/pf.conf`.
- **After nix store rebuild:** Layer 5 (new binary path needs re-signing). Fix: `devenv script sign-beam`.
- **First-time setup:** Layer 5 (codesigning) — most common on macOS Sequoia 15.4+.

## The Layer-2 trap (file present ≠ kernel rules loaded)

Layers 2 and 3 look independent in the table but the dangerous combination is **"pf is enabled AND the anchor file exists AND the kernel anchor is empty."** All three can be true at once after the silent nix-darwin boot failure described above. The check that distinguishes this:

```bash
# Anchor file on disk (file exists, content valid):
cat /etc/pf.anchors/loopback_dev | wc -l      # should be 90

# Anchor LOADED in kernel (this is what actually matters):
sudo pfctl -a loopback_dev -s nat | wc -l     # should be 90; if 0, this is the bug
```

If kernel count is 0 while file count is 90 → `sudo pfctl -f /etc/pf.conf` and re-test.

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
- **Don't silently skip Layer 2 or Layer 3 because sudo prompts** — ask the user for the password. Application-layer hypotheses (Phoenix crash, codegen drift, etc.) almost never produce "Empty reply from server" on this network stack; if you find yourself there without having run `sudo pfctl -a loopback_dev -s nat`, you're guessing.
- **Don't assume `pfctl -s info` = "Enabled" means rules are loaded** — Apple's own pfctl service enables pf at boot independently of whether your anchor loaded. Always check `pfctl -a loopback_dev -s nat` separately.
- **Don't trust nc-vs-Phoenix asymmetry as proof it's the application** — partial NAT (some rules loaded, others not; or rules loaded but Apple's pf service re-flushed) can produce surface-level "nc works, Phoenix doesn't" without the application being at fault.

## Why the nix-darwin daemon may silently fail at boot

The `com.local.pf-loopback` launchd daemon (in `dot_config/nix/darwin/local-dev.nix`) does:

```sh
/sbin/pfctl -f /etc/pf.conf 2>/dev/null
/sbin/pfctl -e 2>/dev/null || true
```

Three problems stacked: `2>/dev/null` swallows stderr, the plist has no `StandardErrorPath`, and there's no post-condition check that the anchor actually loaded. If `/etc/static/pf.anchors/loopback_dev` (a nix store symlink) isn't materialized when the daemon fires at `RunAtLoad`, `pfctl -f` errors out and we never know. The anchor file path resolves correctly *later* — but the daemon never re-runs.

When the kernel anchor is empty post-reboot and you see no relevant entries in `log show --predicate 'eventMessage CONTAINS "pf-loopback"'` beyond the spawn, this is the failure mode. Manual fix is `sudo pfctl -f /etc/pf.conf`; durable fix is to update the daemon to log stderr, verify the anchor loaded, and retry on failure.
