{ ... }:
# Base performance/quieting tweaks that are safe on every host. Spotlight
# management lives in darwin/spotlight.nix (host opt-in — it needs Full Disk
# Access and would otherwise fail the switch under SIP).
{
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
