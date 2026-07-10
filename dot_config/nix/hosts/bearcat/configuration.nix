{
  primaryUser,
  ...
}:
let
  groups = import ../../darwin/cask-groups.nix;
in
{
  networking.hostName = "bearcat";

  # Global PostgreSQL server (demoted from the base — see darwin/default.nix).
  # bearcat opts back in here to keep its always-on home database.
  #
  # TODO(future LLM, on bearcat): confirm with Ian whether he still wants a
  # global PostgreSQL server on THIS machine, or would rather have projects
  # bring their own (mise .tool-versions / devenv / flake) like blackbird does.
  # This was kept on 2026-06-25 as a "for now" decision without checking usage.
  #
  # Spotlight management (exclusions) is demoted from the base too — it needs
  # Full Disk Access or it fails the switch under SIP. bearcat opts in here
  # (it has FDA); blackbird deliberately does not touch Spotlight.
  imports = [
    ../../darwin/postgres.nix
    ../../darwin/spotlight.nix
  ];

  # bearcat is the home machine: add personal/creative groups + heavy SDKs on
  # top of the shared base from darwin/homebrew.nix. (Lists concatenate.)
  homebrew.casks = with groups;
    creative
    ++ media
    ++ personalComms
    ++ personalInfra
    ++ personalMisc
    ++ homeDevExtra
    ++ heavySdks;

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

    echo "bearcat: Screen Sharing (VNC) daemon — port 5900 for vnc://bearcat"
    # macOS 13+ ties Screen Sharing enablement to a TCC-gated toggle in
    # System Settings → General → Sharing → Screen Sharing. The FIRST-TIME
    # enable must be done there manually — nix-darwin can't grant TCC to
    # itself. After that one manual toggle, these commands keep the daemon
    # enabled + running through OS updates, rebuilds, and reboots.
    /bin/launchctl enable system/com.apple.screensharing 2>/dev/null || true
    /bin/launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || \
      /bin/launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
    /bin/launchctl kickstart -k system/com.apple.screensharing 2>/dev/null || true

    # Ensure the primary user is in the Screen Sharing access group.
    # Without this, the daemon runs but macOS refuses VNC logins.
    /usr/sbin/dseditgroup -o edit -a ${primaryUser} -t user com.apple.access_screensharing 2>/dev/null || true

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
