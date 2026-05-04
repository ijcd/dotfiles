# Periodic kitty workspace snapshot. Saves every minute when kitty is
# running, so a reboot/crash loses at most ~1 minute of layout state.
# Snapshots in ~/.local/share/workspace/snapshot-<ts>/. Auto-prunes >7d.
# Save op is sub-100ms (IPC + small file write); negligible at this rate.
{ primaryUser, ... }:
let
  homeDir = "/Users/${primaryUser}";
in {
  launchd.agents.workspace-save = {
    enable = true;
    config = {
      ProgramArguments = [ "${homeDir}/.local/bin/save-workspace" ];
      StartInterval = 60;    # every minute
      RunAtLoad = false;     # wait for first interval (avoids racing with login restore)
      ProcessType = "Background";
      StandardOutPath = "${homeDir}/Library/Logs/workspace-save.log";
      StandardErrorPath = "${homeDir}/Library/Logs/workspace-save.log";
    };
  };
}
