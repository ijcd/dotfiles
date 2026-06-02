{ ... }:
let
  # ═══════════════════════════════════════════════════════════════════════════
  # Dev IP pool: Dynamic allocation for projects/worktrees/branches
  # Managed by dev_ip tool, announced via mDNS (.local)
  # Range: 127.0.0.10 - 127.0.0.99 (90 IPs)
  # ═══════════════════════════════════════════════════════════════════════════
  devIpPoolStart = 10;
  devIpPoolEnd = 99;
  devIpPool = builtins.genList (i: "127.0.0.${toString (i + devIpPoolStart)}")
              (devIpPoolEnd - devIpPoolStart + 1);

  # Static domain mappings (optional - for .test domains via dnsmasq)
  devProjects = [
    # { domain = "myapp.test"; ip = "127.0.0.10"; }
  ];

  # ═══════════════════════════════════════════════════════════════════════════
  # Derived values (don't edit below unless changing behavior)
  # ═══════════════════════════════════════════════════════════════════════════

  # Extract project IPs + pool IPs
  projectIPs = builtins.map (p: p.ip) devProjects;
  devIPs = projectIPs ++ devIpPool;

  # Build domain->IP mapping for dnsmasq
  devDomains = builtins.listToAttrs (
    builtins.map (p: { name = p.domain; value = p.ip; }) devProjects
  );

  # Loopback alias commands (no /nix dependency at runtime)
  ifconfigCmds = builtins.concatStringsSep "; " (
    builtins.map (ip: "/sbin/ifconfig lo0 alias ${ip}") devIPs
  );

  # PF NAT rules - per-IP hairpin routing (NOT /24 — subnet rule breaks cross-IP traffic)
  pfNatRules = builtins.concatStringsSep "\n" (
    builtins.map (ip: "nat on lo0 from ${ip} to ${ip} -> 127.0.0.1") devIPs
  ) + "\n";

  # Script to configure pf.conf and enable PF (no /nix dependency at runtime).
  # Verifies the loopback_dev kernel anchor actually loaded — earlier versions
  # used `pfctl -f … 2>/dev/null` which silently lost a race with nix-darwin's
  # /etc/static activation at boot, leaving the file present on disk but the
  # kernel anchor empty (requires manual `sudo pfctl -f /etc/pf.conf` to
  # recover). Now we log, verify, and retry.
  pfSetupScript = ''
    set -u

    # Add anchor to pf.conf if not present
    if ! grep -q 'loopback_dev' /etc/pf.conf; then
      # Insert after nat-anchor "com.apple/*"
      /usr/bin/awk '/nat-anchor "com.apple\/\*"/{
        print
        print "nat-anchor \"loopback_dev\""
        print "load anchor \"loopback_dev\" from \"/etc/pf.anchors/loopback_dev\""
        next
      }1' /etc/pf.conf > /tmp/pf.conf.new
      /bin/mv /tmp/pf.conf.new /etc/pf.conf
    fi

    # Wait for the anchor file (a nix-store symlink via /etc/static) to be
    # readable. /etc/static is built by nix-darwin activation; if launchd fires
    # this daemon before activation has linked it, pfctl -f errors out.
    for i in 1 2 3 4 5; do
      if [ -r /etc/pf.anchors/loopback_dev ] && [ -s /etc/pf.anchors/loopback_dev ]; then
        break
      fi
      echo "anchor file not readable yet (attempt $i) — sleeping"
      sleep 2
    done

    # Load + enable pf, then verify the kernel anchor actually populated.
    # No 2>/dev/null suppression — errors must be visible in StandardErrorPath.
    for i in 1 2 3; do
      /sbin/pfctl -f /etc/pf.conf
      /sbin/pfctl -e || true   # `pfctl -e` returns non-zero if already enabled
      if /sbin/pfctl -a loopback_dev -s nat 2>&1 | grep -q '^nat'; then
        echo "loopback_dev anchor loaded successfully (attempt $i)"
        exit 0
      fi
      echo "loopback_dev anchor empty after attempt $i — retrying in 3s"
      sleep 3
    done

    echo "FAILED: loopback_dev anchor still empty after 3 attempts" >&2
    exit 1
  '';

in
{
  # ─────────────────────────────────────────────────────────────────────────────
  # DNS: dnsmasq for .test domain resolution
  # ─────────────────────────────────────────────────────────────────────────────
  services.dnsmasq = {
    enable = true;
    addresses = devDomains;
  };

  # Tell macOS to use dnsmasq for .test domains
  environment.etc."resolver/test".text = "nameserver 127.0.0.1\n";

  # ─────────────────────────────────────────────────────────────────────────────
  # PF: NAT rules to fix loopback hairpin routing
  # ─────────────────────────────────────────────────────────────────────────────
  environment.etc."pf.anchors/loopback_dev".text = pfNatRules;

  # ─────────────────────────────────────────────────────────────────────────────
  # Launchd daemons (run at boot, no /nix dependency)
  # ─────────────────────────────────────────────────────────────────────────────

  # 1. Create loopback aliases
  launchd.daemons.loopback-aliases = {
    serviceConfig = {
      Label = "com.local.loopback-aliases";
      ProgramArguments = [ "/bin/sh" "-c" ifconfigCmds ];
      RunAtLoad = true;
    };
  };

  # 2. Configure and enable PF.
  # Capture stdout/stderr to /var/log so silent boot-time failures leave
  # forensics. ThrottleInterval lets launchd actually restart this within
  # the same boot if it exits non-zero (the script already retries 3 times
  # internally; this is the outer safety net).
  launchd.daemons.pf-loopback = {
    serviceConfig = {
      Label = "com.local.pf-loopback";
      ProgramArguments = [ "/bin/sh" "-c" pfSetupScript ];
      RunAtLoad = true;
      StandardOutPath = "/var/log/com.local.pf-loopback.out.log";
      StandardErrorPath = "/var/log/com.local.pf-loopback.err.log";
    };
  };
}
