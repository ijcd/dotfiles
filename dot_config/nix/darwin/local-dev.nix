{ ... }:
let
  # ═══════════════════════════════════════════════════════════════════════════
  # Dev project loopback configuration
  # Add new projects here - everything else is derived from this list
  # ═══════════════════════════════════════════════════════════════════════════
  devProjects = [
    { domain = "theliberties.test"; ip = "127.0.0.10"; }
    # { domain = "myapp.test"; ip = "127.0.0.11"; }
  ];

  # ═══════════════════════════════════════════════════════════════════════════
  # dev_ip pool: Dynamic IP allocation for worktrees/branches
  # These IPs are managed by the dev_ip tool, announced via mDNS (.local)
  # Range: 127.0.0.20 - 127.0.0.39 (20 IPs)
  # ═══════════════════════════════════════════════════════════════════════════
  devIpPoolStart = 20;
  devIpPoolEnd = 39;
  devIpPool = builtins.genList (i: "127.0.0.${toString (i + devIpPoolStart)}")
              (devIpPoolEnd - devIpPoolStart + 1);

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

  # PF NAT rules - fix hairpin routing for each IP
  pfNatRules = builtins.concatStringsSep "\n" (
    builtins.map (ip: "nat on lo0 from ${ip} to ${ip} -> 127.0.0.1") devIPs
  );

  # Script to configure pf.conf and enable PF (no /nix dependency at runtime)
  pfSetupScript = ''
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
    # Load rules and enable PF
    /sbin/pfctl -f /etc/pf.conf 2>/dev/null
    /sbin/pfctl -e 2>/dev/null || true
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

  # 2. Configure and enable PF
  launchd.daemons.pf-loopback = {
    serviceConfig = {
      Label = "com.local.pf-loopback";
      ProgramArguments = [ "/bin/sh" "-c" pfSetupScript ];
      RunAtLoad = true;
    };
  };
}
