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
    echo "bearcat: pmset — remote-access role (AC only)"
    /usr/bin/pmset -c autorestart  1   # come back after power blip
    /usr/bin/pmset -c womp         1   # wake-on-magic-packet (Ethernet reliable, Wi-Fi flaky)
    /usr/bin/pmset -c disablesleep 1   # NEVER sleep on AC (lid-closed clamshell OK)
    /usr/bin/pmset -c sleep        0
    /usr/bin/pmset -c disksleep    0
    /usr/bin/pmset -c displaysleep 10  # display can sleep — GPU stays live

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
