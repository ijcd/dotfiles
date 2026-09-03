# 1. Local-dev DNS split across chezmoi and nix-darwin

**Status**: Accepted (2026-08-19)

## Context

Local dev names (`.test`, `.devip`, `.orb.local`, dev-IP pool loopback) resolve through three unrelated mechanisms that each hijack a different layer: Firefox DoH (name resolution), macOS `/etc/resolver/` + dnsmasq (OS resolver), and Tailscale MagicDNS (routing table + optional whole-system override). A misconfig at any layer breaks local dev with the same symptom: "DNS just doesn't work."

The repo already has two config layers (chezmoi for files, nix-darwin for system state). The question was where each DNS knob belongs and how to keep "add a new loopback TLD" a single-file change.

Precipitating incident: setting up Paperclip in an OrbStack VM. Firefox DoH silently bypassed `/etc/hosts paperclip.lan`. See `/tmp/paperclip-dns-dotfiles-handoff.md` for the full trail.

## Decision

Split the DNS knobs by layer, put each in its natural home, and centralize the extension point:

1. **Firefox `network.trr.excluded-domains` and `network.trr.mode`** → chezmoi `user.js`, applied to all `*.default-release*` profiles via `run_onchange_after_firefox-userjs.sh` at the repo root. Marker-block replacement (`// BEGIN chezmoi: DNS bypass` / `// END`) keeps unrelated user prefs intact.

   - Mode `2` (DoH-with-fallback), not `5` (fully off) — keeps DoH privacy for public browsing.
   - Excluded-domains list is **permissive**: covers likely local TLDs so adding a new one doesn't require a Firefox change. Cost of a TLD being on the list = DoH is skipped for hostnames in that TLD (public lookups still work via system resolver).

2. **`/etc/resolver/<tld>`** entries → nix-darwin (`environment.etc.*`), generated from a single `localDevTlds` list in `dot_config/nix/darwin/local-dev.nix`. Adding a TLD = adding one string to that list.

3. **dnsmasq address bindings** → nix-darwin `services.dnsmasq.addresses`, populated from the existing `devProjects` list. Specific hostname → IP mappings only for now.

4. **`/etc/hosts paperclip.lan`** → dropped. We're moving to Tailscale hostnames for cross-device dev access; loopback shortcut no longer needed.

5. **Tailscale settings** → out of scope for dotfiles. Client daemon state (`accept-routes` etc.) is not file-based; admin-console DNS overrides are tailnet-wide cloud config. Documented in [`architecture/dns-layers.md`](../architecture/dns-layers.md) instead.

6. **Paperclip VM's own config** → not this repo. Belongs in a VM-provisioning repo (cf. `~/work/myclaudes/coretextos` pattern).

## Recipe: add a new local dev TLD `foo`

Two files change, plus one apply cycle:

1. **`dot_config/nix/darwin/local-dev.nix`** — add `"foo"` to the `localDevTlds` list. This generates `/etc/resolver/foo` pointing at `127.0.0.1:53` (dnsmasq).
2. **`dot_config/nix/darwin/local-dev.nix`** — add specific project entries to `devProjects` (`{ domain = "myapp.foo"; ip = "127.0.0.10"; }`) for each hostname that should resolve to loopback. Wildcards *not* yet wired — see Future work.
3. Apply: `chezmoi apply && nixhome-switch`.

Firefox side needs **no change** if the TLD is already in the permissive list (`freedium.cfd, localhost, local, test, devip, lan, orb.local`). If it isn't, add it to the `EXCLUDED_DOMAINS` array at the top of `run_onchange_after_firefox-userjs.sh`.

## Alternatives considered

- **Single source of truth via a shared file** (nix writes `/etc/local-dev-tlds`, Firefox script reads it). Rejected for now: adds a cross-tool coupling for marginal ergonomic gain, and the permissive Firefox list means a new TLD rarely needs a Firefox edit anyway.
- **Firefox mode 5 (DoH fully off)** matches what was set live during the incident. Rejected: sacrifices DoH privacy for public browsing without benefit — mode 2 + exclusions covers local dev equally well.
- **Keep `paperclip.lan` in `networking.hosts`** as belt-and-suspenders alongside Tailscale. Rejected: two names for one thing is a bug factory. Tailscale hostname is authoritative going forward.
- **Migrate Tailscale to nix-managed** (`services.tailscale`). Rejected as a follow-up decision, not part of this ADR. Requires replacing the App Store app; separate scope.

## Consequences

- Adding a loopback TLD is a one-list-edit change in nix (plus specific project entries as needed). No Firefox edit unless the TLD is exotic.
- The Firefox `user.js` **locks** these prefs on every startup — changes via `about:config` revert on next launch. This is the intended trade-off for reproducibility; it does mean a quick debugging tweak is lost when Firefox restarts.
- The permissive `excluded-domains` list means Firefox skips DoH for those TLDs even when browsing legitimate `.dev` / `.internal` sites. Public DNS still works (falls through to system resolver); only DoH privacy is skipped for those specific hostnames.
- Removing `paperclip.lan` from `/etc/hosts` means the loopback shortcut is gone. Access via Tailscale hostname only.

## Future work

- **Wildcard TLD → loopback** for dnsmasq (`address=/foo/127.0.0.1`) so any `*.foo` hostname resolves to `127.0.0.1` without an explicit `devProjects` entry. Requires either nix-darwin's `services.dnsmasq` to grow an `extraConfig`/`.d/` hook, or writing raw dnsmasq config via `environment.etc."dnsmasq.d/*.conf"` if we discover the daemon reads that dir. Investigate module capability first.
- **Migrate Tailscale to nix-managed** — separate ADR if pursued.
