{
  primaryUser,
  ...
}:
{
  networking.hostName = "bearcat";

  # Remote-access role: bearcat stays reachable via Tailscale + Screen Sharing
  # from any tailnet peer. Energy/wake settings are AC-only (-c) so battery
  # behavior stays sane when the laptop travels; sharing daemons enabled
  # declaratively so they survive OS updates.
  #
  # Appends to postActivation (nix-darwin merges `types.lines`), sitting
  # alongside darwin/performance.nix which also writes there.
  system.activationScripts.postActivation.text = ''
    echo "bearcat: pmset — AC (remote-access role at home)"
    /usr/bin/pmset -c womp         1   # wake-on-magic-packet (Ethernet reliable, Wi-Fi flaky)
    /usr/bin/pmset -c sleep        0   # never idle-sleep on AC
    /usr/bin/pmset -c disksleep    0   # never spin down disks on AC
    /usr/bin/pmset -c displaysleep 10  # display can sleep — GPU stays live
    # NOTE: `pmset -c disablesleep 1` is silently rejected on macOS 26.x
    #       (Apple locked it down). Lid-closed-on-AC will sleep unless an
    #       external display is connected (clamshell mode). No software fix.
    # NOTE: `pmset -c autorestart 1` is a Desktops-only setting — MacBook
    #       silently ignores it. Removed to keep this list honest.

    echo "bearcat: pmset — battery (bag-friendly)"
    /usr/bin/pmset -b sleep         3   # idle-sleep after 3 min (was macOS default 15)
    /usr/bin/pmset -b disablesleep  0   # explicit: never block sleep on battery
    /usr/bin/pmset -b tcpkeepalive  0   # skip TCP-triggered wakes in the bag
    #     Trade-off: Handoff-to-iPhone-while-asleep stops working on battery.

    echo "bearcat: enable Screen Sharing (VNC) daemon"
    /bin/launchctl enable   system/com.apple.screensharing 2>/dev/null || true
    /bin/launchctl kickstart -k system/com.apple.screensharing 2>/dev/null || true

    echo "bearcat: enable Remote Login (sshd) — fallback if Tailscale SSH is off"
    # `systemsetup -setremotelogin on` may require Full Disk Access on
    # macOS 12+. If it silently fails, toggle once in System Settings →
    # General → Sharing → Remote Login; nix-darwin can't force this.
    /usr/sbin/systemsetup -setremotelogin on 2>/dev/null || true
  '';

  # host-specific home-manager configuration
  home-manager.users.${primaryUser} = {
    programs.zsh.initContent = ''
      source ${./shell-functions.sh}
    '';
  };
}
