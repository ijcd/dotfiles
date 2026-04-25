{ primaryUser, ... }:
{
  # Spotlight: only index overnight (3:30am–8:00am) to avoid drive thrash.
  # Activation sets correct state based on current hour; launchd handles transitions.
  system.activationScripts.postActivation.text = ''
    # Index home-manager apps for Alfred/Spotlight, then set Spotlight state.
    appDir="/Users/${primaryUser}/Applications/Home Manager Apps"
    if [ -d "$appDir" ]; then
      echo "Spotlight: indexing home-manager apps..."
      /usr/bin/mdutil -a -i on 2>/dev/null || true
      find "$appDir" -maxdepth 1 -name "*.app" -exec /usr/bin/mdimport {} +
      sleep 5
    fi

    hour=$(date +%H)
    if [ "$hour" -ge 3 ] && [ "$hour" -lt 8 ]; then
      echo "Spotlight: inside overnight window, leaving indexing on..."
      /usr/bin/mdutil -a -i on 2>/dev/null || true
    else
      echo "Spotlight: outside overnight window, disabling indexing..."
      /usr/bin/mdutil -a -i off 2>/dev/null || true
    fi
  '';

  launchd.daemons.spotlight-on = {
    serviceConfig = {
      Label = "local.spotlight-on";
      ProgramArguments = [
        "/usr/bin/mdutil" "-a" "-i" "on"
      ];
      StartCalendarInterval = {
        Hour = 3;
        Minute = 30;
      };
    };
  };

  launchd.daemons.spotlight-off = {
    serviceConfig = {
      Label = "local.spotlight-off";
      ProgramArguments = [
        "/usr/bin/mdutil" "-a" "-i" "off"
      ];
      StartCalendarInterval = {
        Hour = 8;
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
