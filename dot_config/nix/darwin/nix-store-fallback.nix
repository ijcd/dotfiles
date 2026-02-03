# Fallback daemon to ensure /nix is mounted after reboot
# Workaround for darwin-store LaunchDaemon sometimes not being bootstrapped
{ ... }:
{
  launchd.daemons.nix-mount-fallback = {
    script = ''
      LOG="/var/log/nix-mount-fallback.log"
      echo "$(date): Checking nix mount..." >> "$LOG"

      if [ ! -d /nix/store ]; then
          echo "$(date): /nix not mounted, attempting fix..." >> "$LOG"

          # Bootstrap darwin-store if not loaded
          if ! launchctl print system/org.nixos.darwin-store &>/dev/null; then
              echo "$(date): Bootstrapping darwin-store..." >> "$LOG"
              launchctl bootstrap system /Library/LaunchDaemons/org.nixos.darwin-store.plist 2>> "$LOG"
          fi

          # Mount by label (portable across machines)
          echo "$(date): Mounting Nix Store..." >> "$LOG"
          /usr/sbin/diskutil mount -mountPoint /nix "Nix Store" >> "$LOG" 2>&1

          # Kick nix-daemon if needed
          if ! launchctl print system/org.nixos.nix-daemon &>/dev/null; then
              echo "$(date): Bootstrapping nix-daemon..." >> "$LOG"
              launchctl bootstrap system /Library/LaunchDaemons/org.nixos.nix-daemon.plist 2>> "$LOG"
          fi

          echo "$(date): Done." >> "$LOG"
      else
          echo "$(date): /nix already mounted." >> "$LOG"
      fi
    '';
    serviceConfig = {
      RunAtLoad = true;
      StartInterval = 30;
      StandardOutPath = "/var/log/nix-mount-fallback.log";
      StandardErrorPath = "/var/log/nix-mount-fallback.log";
    };
  };
}
