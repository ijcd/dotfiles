# Fallback daemon to ensure /nix is mounted and daemon running after reboot
# Uses ProgramArguments directly to avoid wait4path wrapper
{ ... }:
{
  launchd.daemons.nix-mount-fallback = {
    # Don't use `script` - it creates a nix store path wrapped with wait4path
    # Use ProgramArguments directly with inline shell
    serviceConfig = {
      RunAtLoad = true;
      StartInterval = 30;
      StandardOutPath = "/var/log/nix-mount-fallback.log";
      StandardErrorPath = "/var/log/nix-mount-fallback.log";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          LOG="/var/log/nix-mount-fallback.log"
          echo "$(date): Checking nix mount and daemon..." >> "$LOG"

          # Ensure /nix is mounted
          if [ ! -d /nix/store ]; then
              echo "$(date): /nix not mounted, attempting fix..." >> "$LOG"
              /usr/sbin/diskutil mount -mountPoint /nix "Nix Store" >> "$LOG" 2>&1
              sleep 2
          fi

          # Ensure daemon is loaded and running
          if [ -d /nix/store ]; then
              PLIST="/Library/LaunchDaemons/org.nixos.nix-daemon.plist"
              if ! /bin/launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1; then
                  echo "$(date): Daemon not loaded, loading plist..." >> "$LOG"
                  /bin/launchctl load "$PLIST" >> "$LOG" 2>&1
                  sleep 1
              fi
              if ! /bin/launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1; then
                  echo "$(date): Daemon still not running, kickstarting..." >> "$LOG"
                  /bin/launchctl kickstart -k system/org.nixos.nix-daemon >> "$LOG" 2>&1
              else
                  echo "$(date): Daemon running." >> "$LOG"
              fi
          else
              echo "$(date): /nix still not mounted, cannot start daemon." >> "$LOG"
          fi
        ''
      ];
    };
  };
}
