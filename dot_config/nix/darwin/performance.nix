{ primaryUser, ... }:
{
  # Spotlight: Disable indexing on data paths we don't need searched
  # Note: /System, /usr, /nix are read-only or special mounts - can't modify
  # Alfred needs /Applications and ~ indexed
  system.activationScripts.postActivation.text = ''
    echo "Configuring Spotlight indexing (data volumes only)..."
    # These are on the writable data volume
    /usr/bin/mdutil -i off /Library 2>/dev/null || true
    /usr/bin/mdutil -i off /private 2>/dev/null || true
    /usr/bin/mdutil -i off /opt 2>/dev/null || true
  '';

  # Disable Siri learning daemon (duetexpertd)
  # Powers: suggested apps, Siri suggestions, app predictions
  # Safe to disable if you don't use Siri
  launchd.daemons.disable-duetexpertd = {
    serviceConfig = {
      Label = "local.disable-duetexpertd";
      ProgramArguments = [
        "/bin/launchctl"
        "disable"
        "system/com.apple.duetexpertd"
      ];
      RunAtLoad = true;
    };
  };

  # Disable related Siri/suggestion daemons
  launchd.daemons.disable-siri-daemons = {
    serviceConfig = {
      Label = "local.disable-siri-daemons";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          /bin/launchctl disable system/com.apple.suggestd
          /bin/launchctl disable system/com.apple.proactiveeventtrackerd
        ''
      ];
      RunAtLoad = true;
    };
  };
}
