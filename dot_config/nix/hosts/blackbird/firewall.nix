# blackbird firewall (pf) — blackbird only.
#
# Remote Login (22) and Screen Sharing (5900) bind to ALL interfaces (macOS has
# no per-interface toggle), so they would be reachable on any Wi-Fi/Ethernet the
# laptop joins. This pf ruleset blocks inbound 22/5900 EXCEPT from the Mac itself
# (loopback) and OrbStack VMs (the 192.168.139.0/24 + fd07:b51a:cc66::/48 orb
# networks) — so those services are reachable only locally and via the
# nixos-antares jump box, never on an untrusted network. Everything else is
# untouched (pf default-passes unmatched traffic).
#
# Matched by SOURCE, not interface, so nothing needs to exist at boot (the orb
# bridge is created lazily when a machine starts). `block drop` = silent (ports
# read as filtered on the LAN, not merely closed).
#
# Loaded at boot via a LaunchDaemon (pf resets to /etc/pf.conf on reboot) and
# immediately on rebuild (postActivation). The ruleset mirrors Apple's own
# anchor scaffolding so com.apple pf usage (NAT, etc.) keeps working.
{ pkgs, ... }:
let
  pfConf = pkgs.writeText "blackbird-remote-pf.conf" ''
    # Apple defaults — mirror /etc/pf.conf so the com.apple anchors still load.
    scrub-anchor "com.apple/*"
    nat-anchor "com.apple/*"
    rdr-anchor "com.apple/*"
    dummynet-anchor "com.apple/*"
    anchor "com.apple/*"
    load anchor "com.apple" from "/etc/pf.anchors/com.apple"

    # Remote Login (22) + Screen Sharing (5900): local machine + OrbStack only.
    block drop in proto tcp to any port { 22 5900 }
    pass in quick on lo0 proto tcp to any port { 22 5900 }
    pass in quick inet  proto tcp from 192.168.139.0/24    to any port { 22 5900 }
    pass in quick inet6 proto tcp from fd07:b51a:cc66::/48 to any port { 22 5900 }
  '';
in
{
  # Reload our ruleset at every boot (pf reverts to /etc/pf.conf otherwise).
  launchd.daemons.blackbird-remote-pf = {
    script = "/sbin/pfctl -f ${pfConf} -E";
    serviceConfig.RunAtLoad = true;
  };

  # Apply immediately on rebuild too (no reboot needed).
  system.activationScripts.postActivation.text = ''
    echo "blackbird: pf — Remote Login/Screen Sharing limited to loopback + OrbStack"
    /sbin/pfctl -f ${pfConf} -E 2>/dev/null || true
  '';
}
