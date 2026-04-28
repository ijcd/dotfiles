{ primaryUser, ... }:
{
  # Spotlight: keep indexing enabled so Alfred can discover all apps.
  # Exclude noisy paths to reduce drive thrash.
  system.activationScripts.postActivation.text = ''
    echo "Spotlight: enabling indexing..."
    /usr/bin/mdutil -a -i on 2>/dev/null || true

    # Exclude paths we don't need searched
    /usr/bin/mdutil -i off /Library 2>/dev/null || true
    /usr/bin/mdutil -i off /private 2>/dev/null || true
    /usr/bin/mdutil -i off /opt 2>/dev/null || true

    # Ensure home-manager apps are indexed for Alfred
    appDir="/Users/${primaryUser}/Applications/Home Manager Apps"
    if [ -d "$appDir" ]; then
      echo "Spotlight: importing home-manager apps..."
      find "$appDir" -maxdepth 1 -name "*.app" -exec /usr/bin/mdimport {} +
    fi
  '';

  # Re-enable Spotlight every morning in case it was stopped/muted and forgotten.
  launchd.daemons.spotlight-morning = {
    serviceConfig = {
      Label = "local.spotlight-morning";
      ProgramArguments = [
        "/usr/bin/mdutil" "-a" "-i" "on"
      ];
      StartCalendarInterval = {
        Hour = 7;
        Minute = 0;
      };
    };
  };

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
