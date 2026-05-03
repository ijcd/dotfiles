{ primaryUser, lib, ... }:
let
  homeDir = "/Users/${primaryUser}";

  # Directories to exclude from Spotlight via the Privacy plist.
  # These show up in Settings > Siri & Spotlight > Spotlight Privacy.
  spotlightExclusions = [
    # System paths
    "/Library"
    "/private"
    "/opt"

    # Package managers / language runtimes
    "/usr/local/Cellar"
    "/usr/local/Homebrew"
    "/nix"
    "${homeDir}/.cargo"
    "${homeDir}/.npm"
    "${homeDir}/.hex"
    "${homeDir}/.mix"
    "${homeDir}/.cache"
    "${homeDir}/.nix-defexpr"
    # .nix-profile omitted: it's a symlink into /nix/store, already covered by /nix

    # Infrastructure / container tools
    "${homeDir}/.docker"
    "${homeDir}/.fly"
    "${homeDir}/.pulumi"

    # App data (caches/databases)
    "${homeDir}/.local/share"
    "${homeDir}/.ollama"   # local LLM model blobs (multi-GB, opaque binaries)

    # Dev projects (blog and resume kept indexed)
    "${homeDir}/work"
  ];

  plist = "/System/Volumes/Data/.Spotlight-V100/VolumeConfiguration.plist";
  pb = "/usr/libexec/PlistBuddy";

  # Desired exclusions as a file (one path per line) for the activation script
  desiredFile = builtins.toFile "spotlight-exclusions"
    (lib.concatMapStringsSep "\n" (dir: dir) spotlightExclusions + "\n");
in
{
  # Spotlight: keep indexing enabled so Alfred can discover all apps.
  # Exclude noisy paths to reduce drive thrash.
  system.activationScripts.postActivation.text = ''
    echo "Spotlight: enabling indexing..."
    /usr/bin/mdutil -a -i on 2>/dev/null || true

    # Sync Spotlight Privacy exclusions (authoritative — plist matches nix list exactly)
    echo "Spotlight: syncing directory exclusions..."
    ${pb} -c "Delete :Exclusions" ${plist} 2>/dev/null || true
    ${pb} -c "Add :Exclusions array" ${plist}
    while IFS= read -r dir; do
      if [ -d "$dir" ]; then
        echo "  $dir"
        ${pb} -c "Add :Exclusions: string '$dir'" ${plist}
      fi
    done < ${desiredFile}

    # Restart mds so the GUI picks up plist changes
    /bin/launchctl kickstart -k system/com.apple.metadata.mds

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
