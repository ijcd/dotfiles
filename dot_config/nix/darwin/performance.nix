{ primaryUser, ... }:
{
  # Spotlight: only index /Applications and home directory
  # Reduces CPU/IO from mds_stores constantly reindexing system paths
  system.activationScripts.postActivation.text = ''
    echo "Configuring Spotlight indexing scope..."
    # Disable indexing on system paths
    /usr/bin/mdutil -i off /System 2>/dev/null || true
    /usr/bin/mdutil -i off /Library 2>/dev/null || true
    /usr/bin/mdutil -i off /usr 2>/dev/null || true
    /usr/bin/mdutil -i off /var 2>/dev/null || true
    /usr/bin/mdutil -i off /private 2>/dev/null || true
    /usr/bin/mdutil -i off /opt 2>/dev/null || true
    /usr/bin/mdutil -i off /nix 2>/dev/null || true

    # Ensure these ARE indexed (for Alfred)
    /usr/bin/mdutil -i on /Applications 2>/dev/null || true
    /usr/bin/mdutil -i on "/Users/${primaryUser}" 2>/dev/null || true
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
