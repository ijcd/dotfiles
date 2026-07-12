# Remote-access role — blackbird only.
#
# Makes blackbird reachable as an SSH + Screen Sharing target so the
# nixos-antares OrbStack VM (the tailnet-facing jump box) can broker into it.
# blackbird itself stays OFF the tailnet; its only remote exposure is to a VM
# running on itself, reached over the OrbStack network (host gateway 192.168.139.1).
#
# Mirrors hosts/bearcat's remote-access block, tuned for the work laptop:
#   * Remote Login (sshd) + Screen Sharing (VNC :5900) enabled and kept running.
#   * pmset: stay awake on AC so the jump box is reachable while docked; sleep on
#     battery (bag-friendly). This is the knob that decides unattended reach —
#     drop the AC block if you only want blackbird reachable on demand.
#
# FIRST-TIME: Screen Sharing and Remote Login are TCC-gated — enable each ONCE by
# hand in System Settings → General → Sharing (nix-darwin can't grant itself TCC).
# After that, these keep them enabled across rebuilds / updates / reboots.
#
# Appends to postActivation (nix-darwin merges types.lines) alongside
# darwin/performance.nix.
{ primaryUser, ... }:
{
  system.activationScripts.postActivation.text = ''
    echo "blackbird: pmset — AC (stay reachable for the OrbStack jump box)"
    /usr/bin/pmset -c womp         1   # wake-on-magic-packet
    /usr/bin/pmset -c sleep        0   # never idle-sleep on AC
    /usr/bin/pmset -c disksleep    0   # never spin down disks on AC
    /usr/bin/pmset -c displaysleep 10  # display may sleep — machine stays live

    echo "blackbird: pmset — battery (bag-friendly)"
    /usr/bin/pmset -b sleep        3   # idle-sleep after 3 min on battery

    echo "blackbird: Screen Sharing (VNC) daemon — :5900 for the VM to relay"
    /bin/launchctl enable system/com.apple.screensharing 2>/dev/null || true
    /bin/launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || \
      /bin/launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
    /bin/launchctl kickstart -k system/com.apple.screensharing 2>/dev/null || true
    # Primary user must be in the Screen Sharing access group or VNC logins are refused.
    /usr/sbin/dseditgroup -o edit -a ${primaryUser} -t user com.apple.access_screensharing 2>/dev/null || true

    echo "blackbird: enable Remote Login (sshd) — the VM jumps through this"
    /usr/sbin/systemsetup -setremotelogin on 2>/dev/null || true
  '';
}
