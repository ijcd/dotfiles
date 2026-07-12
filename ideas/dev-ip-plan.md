# dev-ip — plan

CLI to allocate one loopback IP + hostname per workspace/branch, statically, so multiple
isolated dev instances (docker **or** native) run at once on one machine. Resolution via a
dedicated dnsmasq over a user-writable dir. No mDNS, no `/etc/hosts` edits, no sudoers.
`lunar-sim` is one consumer.

Prior art (do not reinvent): `~/.local/share/chezmoi/ideas/{dev-ip-manager,dev_ip-hex-package-spec,worktree-mdns-isolation,per-project-dev-infrastructure}.md` and `dot_config/nix/darwin/local-dev.nix`.

## Hard requirements

- **Idempotent** — every host mutation is guarded by a detect; re-running converges, never duplicates.
- **Portable** — works on the nix-provisioned laptop (defer to what nix already manages) and a stock Mac (install it).
- **Safe repeatedly** — never clobbers nix-managed resources; deterministic file content; `--check` dry-run.
- Static mappings, CLI-managed lifetime (`alloc`/`free`), optional on-demand `gc`. No daemon watching, no mDNS.

## Architecture

```
  workspace ─ dev-ip ip <name> ─▶ ~/.local/share/dev-ip/hosts.d/<name>  ("127.0.0.11 gchs.devip")
                                        │ (auto-reload)
                                   dnsmasq  (user LaunchAgent, 127.0.0.1:5354, --hostsdir)
                                        ▲ routed by
                                   /etc/resolver/devip  ("nameserver 127.0.0.1" + "port 5354")
  bind anything to the IP:  docker  LB_IP=127.0.0.11 compose up   → http://gchs.devip:8080
                            native  mix phx.server --ip 127.0.0.11 → http://gchs.devip:4000
  IPs only work on macOS because of:  loopback aliases + per-IP PF hairpin NAT (below)
```

`hosts.d/<name>` is the single source of truth — registry **and** what dnsmasq serves. `alloc` scans it for used IPs, `free` = `rm`.

### TLD (configurable, multiple)

Default `.devip`. `provision --tld <a>[,<b>…]` writes one `/etc/resolver/<tld>` per TLD — all routed to the **same** `:5354` dnsmasq, which answers any `hosts.d` name regardless of suffix. So N TLDs = N resolver files, one daemon; adding/removing one is a single `/etc/resolver/<tld>` file (the only per-TLD sudo). `.test` is deliberately **not** reused: nix owns it on `:53` (and it's currently idle — `devProjects` empty, resolves NXDOMAIN), and two dnsmasqs can't share `:53`/`.test`.

## The macOS routing requirement (non-negotiable)

Loopback aliases are dead on macOS without a **per-IP PF hairpin NAT** rule (`per-project-dev-infrastructure.md`, `local-dev.nix`):

```
nat on lo0 from 127.0.0.11 to 127.0.0.11 -> 127.0.0.1    # ONE rule per alias IP — NOT a /24
```

- Per-IP, never `/24` (`local-dev.nix`: *"subnet rule breaks cross-IP traffic"*).
- Loaded as a pf anchor into `/etc/pf.conf`, then `pfctl -f` + `pfctl -e`.
- Boot-race guard: `pfctl -f` can run before `/etc/static` activation; must **retry + verify the anchor populated** (`pfctl -a <anchor> -s nat | grep '^nat'`).

## Provisioning — idempotent, converging

`dev-ip provision` runs these steps; each is detect-then-maybe-mutate. `dev-ip provision --check` prints state and mutates nothing. `dev-ip doctor` = `--check` + an end-to-end resolve probe.

| # | Step | Detect (skip if true) | Mutate (only if needed) | Sudo |
|---|------|----------------------|-------------------------|------|
| 1 | classify host | — | set `MANAGED_BY_NIX=1` if `launchctl print system/com.local.loopback-aliases` exists | no |
| 2 | loopback aliases | nix-managed, **or** all pool IPs already in `ifconfig lo0` | install `~/Library/LaunchAgents/dev-ip-loopback.plist` (runs `ifconfig lo0 alias` per IP; re-adding an alias is benign) | yes¹ |
| 3 | PF hairpin | nix anchor present: `pfctl -a loopback_dev -s nat` shows the rules | write `/etc/pf.anchors/dev-ip` (deterministic); add anchor lines to `/etc/pf.conf` **only if** `grep -q dev-ip /etc/pf.conf` fails; `pfctl -f` + `-e`; retry/verify | yes |
| 4 | dnsmasq binary | `command -v dnsmasq` | report + instruct (`brew install dnsmasq`); do **not** auto-install without `--yes` | no |
| 5 | dnsmasq agent | plist present **and** `launchctl print gui/$UID/dev-ip-dnsmasq` running with current config hash | write `dev-ip-dnsmasq.plist` (deterministic); `launchctl bootout` then `bootstrap` (clean reload) | no |
| 6 | resolver | `/etc/resolver/devip` byte-equal to desired | `printf 'nameserver 127.0.0.1\nport 5354\n' | sudo tee /etc/resolver/devip` | yes |
| 7 | hosts.d | dir exists | `mkdir -p ~/.local/share/dev-ip/hosts.d` | no |
| 8 | verify | — | write probe → `dig +short @127.0.0.1 -p 5354 probe.devip` == IP → rm probe; fail loudly if not | no |

¹ steps 2–3 are the *only* sudo on a stock Mac; on the nix laptop steps 2–3 are **skipped** (detected), leaving **step 6 (`/etc/resolver/devip`) as the sole sudo**.

### Idempotency rules (apply to every step)

- **Detect before mutate.** `grep`/`cmp`/`exists`/`launchctl print` gate each change.
- **Deterministic content** → rewriting a file is a safe no-op-if-unchanged (compare with `cmp -s`, write only on diff).
- **launchd reload** = `bootout` (ignore error) then `bootstrap`; never assume prior state.
- **`/etc/pf.conf`** — append anchor lines only when absent; never duplicate; leave Apple's lines untouched.
- **Defer to nix** — if a nix-managed loopback/pf manager exists, do not install a second one; dev-ip's dnsmasq (:5354, `.devip`) always runs regardless, isolated from nix's (:53, `.test`).
- **Re-run = converge.** Running `provision` twice in a row makes zero changes the second time (assert this in a test: second run's mutate-count == 0).

## De-provision

`dev-ip deprovision` — reverse only what dev-ip installed: bootout+rm the dnsmasq agent plist; `sudo rm /etc/resolver/devip`; if dev-ip installed the pf anchor (not nix's), remove its `/etc/pf.conf` lines + anchor file and reload; leave the loopback plist if nix owns it. Idempotent (missing = fine).

## CLI surface

| Command | Does | Sudo |
|---|---|---|
| `provision` / `provision --check` / `doctor` | converge host / dry-run / verify | 6 only (laptop) |
| `alloc <name>` · `ip <name>` | write `hosts.d/<name>`, print IP | none |
| `free <name>` · `ls` · `gc` | rm file / list / prune names whose `docker compose -p lunar-<name> ps -q` is empty | none |
| `deprovision` | remove dev-ip's host changes | resolver/pf rm |

- Name → IP allocation: stable (reuse if a `hosts.d/<name>` exists), else lowest-free in `127.0.0.10–99`; `flock` the dir for concurrent callers. Sanitize name → DNS label (`/`→`-`, drop non-`[a-z0-9-]`, ≤63).
- `gc` is the one liveness nod — on demand, no daemon.

## Files

```
bin/dev-ip                              # bash CLI
bin/lunar-sim                           # consumer: LB_IP=$(dev-ip ip <name>); compose -p lunar-<name> up
~/.local/share/dev-ip/hosts.d/<name>    # user-owned registry + dnsmasq source
~/Library/LaunchAgents/dev-ip-dnsmasq.plist   # user dnsmasq :5354 --hostsdir=hosts.d --no-hosts --no-resolv
~/Library/LaunchAgents/dev-ip-loopback.plist  # stock-Mac only; nix laptop skips
/etc/pf.anchors/dev-ip                  # stock-Mac only; nix laptop skips
/etc/resolver/devip                       # both (the one always-sudo bit)
```

## lunar-sim integration

`lunar-sim up <name>` → `LB_IP=$(dev-ip ip <name>)` → `docker compose -p lunar-<name> up -d --scale …`.
`down` = compose down (mapping persists; `dev-ip free` releases). The `${LB_IP:-127.0.0.1}` compose wiring already landed; the `/etc/hosts` code currently in `lunar-sim` gets **removed** and replaced by the `dev-ip` call.

## Open decisions

- ~~TLD~~ **decided**: default `.devip`, `--tld` configurable, multiple allowed (see TLD section).
- **dnsmasq install** — detect + instruct by default; `provision --yes` may `brew install`. Nix laptop already has the binary.
- **Language** — bash, `bin/dev-ip`, co-located here now; extract to dotfiles/its own repo later.

## Test plan (what "works repeatedly" means)

- `provision` on a stock Mac (VM) from clean → all 8 steps green; `doctor` resolves probe.
- `provision` again → **zero mutations** (idempotence assertion).
- `provision` on the nix laptop → steps 2–3 skipped, only `/etc/resolver/devip` written; `doctor` green.
- `alloc a; alloc b; ls` → distinct IPs; `alloc a` again → same IP (stable).
- Kill dnsmasq agent → `launchd` restarts it (KeepAlive); `doctor` still green.
- `deprovision` → resolver/pf/agent gone; re-`provision` → back, no residue.
