{ primaryUser, lib, config, pkgs, ... }:
{
  imports = [
    ./packages.nix
    ./git.nix
    ./shell.nix
    ./mise.nix
    ./direnv.nix
    ./emacs.nix
    ./ollama.nix
  ];

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  # Copy .app bundles to ~/Applications so Spotlight/Alfred can find them.
  # Default is linkApps (symlinks) for stateVersion < 25.11; override to copyApps.
  targets.darwin.copyApps.enable = true;
  targets.darwin.linkApps.enable = false;

  home = {
    username = primaryUser;
    stateVersion = "25.05";
    sessionVariables = {
      # shared environment variables
    };

    # create .hushlogin file to suppress login messages
    file.".hushlogin".text = "";
  };
}
