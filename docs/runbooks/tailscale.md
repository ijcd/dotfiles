# Tailscale on bearcat — remote-access runbook

**Role**: bearcat (MacBook Pro 16" 2019, Intel) sits at home plugged in. Any client Mac on the tailnet reaches it via SSH and macOS Screen Sharing (`vnc://bearcat`) whether direct P2P (WireGuard) or DERP-relayed.

**Declarative pieces** (persisted through nix-darwin + chezmoi):
- Cask: `tailscale` in `dot_config/nix/darwin/homebrew.nix`
- Energy + sharing daemons: `system.activationScripts.postActivation` in `dot_config/nix/hosts/bearcat/configuration.nix`
- Aliases: `ts`, `tsstatus`, `tsnetcheck`, `tspong` in `dot_config/zsh/aliases.zsh`

**Auth identity** (one-time, chosen at first sign-in):
- **Primary**: passkey in iCloud Keychain — phishing-resistant, syncs to iPhone/iPad, Face/Touch ID
- **Fallback**: GitHub SSO (matches your `gh` CLI identity) if the passkey path breaks
- **Future backup**: register a Yubikey as a second passkey once acquired — covers BT-less machines and iCloud failure

**Prereq**: iCloud Keychain enabled on Mac + iPhone (System Settings → Apple ID → iCloud → Passwords & Keychain).

**Interactive pieces** (one-time, per device):
- `sudo tailscale up --ssh` on each node — auth via browser, passkey approval
- MagicDNS + HTTPS certs on in admin console

---

## First-time setup on bearcat

After `nixhome-rebuild` has installed the cask:

```sh
# One-time auth. --ssh enables Tailscale SSH (ACL-managed, no key wrangling).
sudo tailscale up --ssh --accept-routes=false
# Browser opens → click "Sign in with passkey" → Touch ID → done.
# (If your Tailscale tailnet doesn't exist yet, create it here — pick passkey
# as the account identity, NOT GitHub, so the tailnet is passkey-rooted.)

# Confirm the node is up and has a tailnet IP.
tailscale status
# expect: 100.x.y.z bearcat ijcd@ macOS -
```

In the [admin console](https://login.tailscale.com/admin):
1. **DNS** → enable **MagicDNS** → enable **HTTPS certs**.
2. Confirm bearcat is listed under **Machines**.

## Adding another Mac (has iCloud Keychain, has passkey via sync)

```sh
sudo tailscale up --ssh --accept-routes=false
# Browser opens → "Sign in with passkey" → Touch ID (passkey is in iCloud Keychain).
tailscale status              # should list bearcat as a peer
```

## Adding a Linux / Windows / non-Apple machine

Two paths depending on whether the machine has Bluetooth:

### With Bluetooth — cross-device passkey via phone (QR)

```sh
sudo tailscale up --ssh --accept-routes=false
# Browser opens → "Sign in with passkey" → "Use a device nearby"
# → shows QR code
# → open Camera on iPhone, point at QR
# → iPhone: "Sign in to login.tailscale.com?" → Face ID
# → machine's browser gets signed, logged in
```

Requires: iOS 16+, Bluetooth on both ends, both online.

### Without Bluetooth (headless server, cloud VM, BT-less desktop) — auth key

Passkey/browser flow isn't required at all. In [admin console](https://login.tailscale.com/admin) → **Settings → Keys → Generate auth key**:

- **Expiration**: 90 days (or shorter for short-lived work)
- **Reusable**: no (unless provisioning several boxes)
- **Ephemeral**: yes for throwaway VMs — auto-deregisters when the tailscaled daemon stops

Then on the machine:
```sh
sudo tailscale up --ssh --authkey tskey-...
```

Rotate the key from admin console after use so any leaked copy is dead.

### Emergency access from a machine you don't control

See "Connecting from an uncontrolled machine" below.

## Verify

The check that matters — **direct P2P, not DERP**:

```sh
tspong bearcat                # tailscale ping bearcat
# expect: pong from bearcat ... via 100.x:41641 in Xms
# BAD:    pong from bearcat ... via DERP(sjc) in Xms
```

Then the actual use case:

```sh
ssh ijcd@bearcat              # MagicDNS resolves to 100.x
open vnc://bearcat            # Screen Sharing.app opens the desktop
nc -zv bearcat 5900           # VNC port reachable
```

## Recovery

### Node went offline

1. From admin console: check **Last seen** and **Expiry**. If expired, re-auth (below).
2. If lost network at home: bearcat comes back automatically when Tailscale daemon reconnects.
3. If daemon is stuck:
   ```sh
   sudo launchctl kickstart -k system/com.tailscale.tailscaled
   ```

### Re-auth after expiry (default 180 days)

On bearcat locally, or over Tailscale SSH:
```sh
sudo tailscale up --ssh --accept-routes=false --force-reauth
```

### `tspong` reports `DERP` instead of direct

Symmetric NAT or UDP-blocked. Diagnose:
```sh
tailscale netcheck            # on BOTH ends
```

Look for:
- `Mapping varies by destination: true` → symmetric NAT (hard to fix; needs UPnP/NAT-PMP on your router, or public IPv6 both sides)
- `PortMapping: <none>` → router doesn't advertise UPnP/PMP; enable it
- UDP blocked → firewall

Fallback: DERP works, just slower. GUI Screen Sharing over DERP is noticeably laggy but functional.

### Rotate / revoke a device

Admin console → **Machines** → device → **Remove** or **Disable key expiry**.

To force *all* devices to re-auth: **DNS/Settings → Rotate device authorization**.

### Lost the passkey (iCloud sync broken, all Apple devices unavailable)

Until you have a Yubikey backup, the recovery path is:
1. Sign in to admin console via **magic link email** (Tailscale sends a login link to the account's email)
2. Add a new device via the browser session
3. Re-establish the passkey from a working iCloud device once restored

Once you have a Yubikey: register it as a **second** passkey in the admin console → Account settings. That gives you an offline, phone-independent recovery path — plug in Yubikey, touch, done.

## Connecting from an uncontrolled machine

Ranked by trust level of the borrowed machine.

**Tier 1 — your phone (default).** Termius / Blink Shell for SSH; Screens or VNC Viewer for graphical. Same tailnet identity, no new auth needed.

**Tier 2 — semi-trusted (friend's laptop).** Generate an **ephemeral auth key** in admin console, use `--ephemeral` flag on `tailscale up`. Do the work. `sudo tailscale logout` — node auto-deregisters. Rotate the auth key after.

**Tier 3 — hostile (kiosk, hotel biz center).** Don't. Use the phone. If you must: boot Ubuntu Live USB, install Tailscale in RAM, use ephemeral key + phone-mediated passkey. Nothing persists on the host when you shut down.

Session content is never protected — anything you type or view goes through the host's keyboard/screen. Tailscale secures the transport only.

### macOS Sharing daemons dropped

If SSH stops working but Tailscale is up: the activation script *should* have re-enabled sshd, but Full Disk Access requirements can defeat it. Toggle:

**System Settings → General → Sharing → Remote Login** off/on.

Same for Screen Sharing.

## Reference

- `pmset -g` shows current wake/sleep. AC-side should show `disablesleep 1 sleep 0 disksleep 0 womp 1 autorestart 1`.
- `/etc/tailscale/derpmap.json` — DERP relay list (rarely edited).
- Tailscale logs: `sudo tailscale debug daemon-logs` or Console.app filtered on "tailscale".
- Admin: https://login.tailscale.com/admin/machines
