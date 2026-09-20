# Local-dev DNS layers

**Status**: current-state (mutable — edit as system changes)
**Applies to**: every host this dotfiles repo lands on (both `bearcat` and `blackbird` today)
**Related**: [ADR-0001](../decisions/0001-local-dev-dns-layers.md), [runbooks/tailscale](../runbooks/tailscale.md)

Local dev on any host that pulls this repo juggles four independent DNS mechanisms. This doc names each layer, shows the request flow, and lists where the knob for each lives.

## Request flow

```
                     ┌────────────────────────────────────────┐
                     │  Firefox                                │
                     │                                         │
                     │  For each hostname, ask:                │
                     │    "is TLD in trr.excluded-domains?"    │
                     │       yes → OS resolver (drop out)      │
                     │       no  → DoH   ──►  Cloudflare/etc.  │
                     │                                         │
                     │  (mode 2 = DoH-with-fallback)           │
                     └───────────────────┬────────────────────┘
                                         │  excluded TLDs only
                                         ▼
    ─────────────────────  macOS resolver (scutil / DNSServiceRef) ───────────────────
                                         │
             ┌───────────────────┬───────┴──────────┬─────────────────┐
             ▼                   ▼                  ▼                 ▼
    ┌─────────────────┐  ┌───────────────┐  ┌──────────────┐  ┌──────────────┐
    │ TLD = .local ?  │  │ /etc/resolver │  │ /etc/hosts   │  │ default      │
    │  → mDNS         │  │   /test       │  │ (static map) │  │  resolver    │
    │    (mDNS-       │  │   /devip      │  │              │  │  = your ISP/ │
    │    Responder,   │  │   /orb.local  │  │              │  │    Tailscale │
    │    Bonjour)     │  │   (add here)  │  │              │  │    MagicDNS  │
    │                 │  │               │  │              │  │              │
    │  ← used by      │  │  each file →  │  │              │  │              │
    │    OrbStack     │  │  "use these   │  │              │  │              │
    │    & Zeroconf   │  │   nameservers │  │              │  │              │
    │                 │  │   for this    │  │              │  │              │
    │                 │  │   TLD"        │  │              │  │              │
    └─────────────────┘  └──────┬────────┘  └──────────────┘  └──────┬───────┘
                                │                                    │
                    ┌───────────┴──────────┐               ┌─────────┴──────────┐
                    ▼                      ▼               ▼                    ▼
             ┌─────────────┐        ┌─────────────┐  ┌──────────┐        ┌────────────┐
             │  dnsmasq    │        │  dnsmasq    │  │  Router  │        │ Tailscale  │
             │  :53 (loop) │        │  :5354 (dev │  │  or ISP  │        │ 100.100.   │
             │             │        │  ip pool)   │  │  DNS     │        │ 100.100    │
             │  Knows:     │        │             │  │          │        │            │
             │   .test     │        │  Knows:     │  │          │        │ *.ts.net   │
             │             │        │   .devip    │  │          │        │ + optional │
             │  (via       │        │             │  │          │        │ "override  │
             │  devProjects│        │             │  │          │        │ local DNS" │
             │  entries)   │        │             │  │          │        │            │
             │             │        │             │  │          │        │            │
             │  → returns  │        │  → returns  │  │          │        │            │
             │  configured │        │  127.0.0.X  │  │          │        │            │
             │  IPs        │        │  (dev pool) │  │          │        │            │
             └─────────────┘        └─────────────┘  └──────────┘        └────────────┘
```

## Concerns / knobs / homes

| Concern | Knob | Where it's set |
|---|---|---|
| Firefox routes local names to OS instead of DoH | `network.trr.excluded-domains` in `user.js` | chezmoi: [`run_onchange_after_firefox-userjs.sh`](../../run_onchange_after_firefox-userjs.sh) |
| Firefox DoH posture (on / off / fallback) | `network.trr.mode` in `user.js` | same file |
| macOS routes a TLD to a specific resolver | `/etc/resolver/<tld>` | nix-darwin: [`darwin/local-dev.nix`](../../dot_config/nix/darwin/local-dev.nix) via `localDevTlds` list |
| Loopback aliases (`127.0.0.10-99`) for dev-IP pool | `ifconfig lo0 alias` via launchd | same file |
| PF NAT hairpin routing for loopback pool | `/etc/pf.anchors/loopback_dev` | same file |
| Specific hostname → loopback IP for dev projects | `services.dnsmasq.addresses` (via `devProjects`) | same file |
| Wildcard `*.tld → 127.0.0.1` (any subdomain) | not yet wired — see ADR-0001 §Future work | — |
| Tailscale doesn't hijack whole DNS | admin console: **DNS → "Override local DNS" = off** | tailnet cloud config (not dotfile-able) |
| OrbStack VM hostnames (`foo.orb.local`) | OrbStack daemon publishes via mDNS | nothing to do (OrbStack owns it) |

## Layer ordering — why bugs are usually at one specific layer

The three layers Firefox → macOS resolver → dnsmasq are **strictly top-down**, not competing. Firefox decides *whether* to consult the OS at all → OS decides *which resolver* by TLD → the chosen resolver decides *what the answer is*. A misconfig at any layer looks like "DNS just doesn't work" but the fix is always at the *specific* layer making the wrong choice.

- `/etc/resolver/<tld>` is a **suffix rule**, not a full-DNS override. macOS uses it *in addition to* the default resolver — the default doesn't get bypassed for other TLDs. Safe to add many loopback TLDs without breaking public DNS.
- **mDNS is a fourth mechanism outside all of this.** `.local` is handled by mDNSResponder over multicast UDP; it never touches `/etc/resolver` or dnsmasq. That's why OrbStack's `foo.orb.local` "just works" even with no resolver config.
- **Tailscale's "Override local DNS" is the layer-3 hijack** to watch out for. When on, Tailscale hands out `100.100.100.100` as the *primary* system resolver — `/etc/resolver/*` per-TLD overrides still win, but the default resolver bypasses your ISP.

## Add a new local dev TLD

See ADR-0001 §Recipe.
