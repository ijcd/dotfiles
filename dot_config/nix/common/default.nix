{ primaryUser, lib, ... }:
{
  imports = [
    ./packages.nix
    ./git.nix
    ./shell.nix
    ./mise.nix
    ./direnv.nix
    ./emacs.nix
  ];

  nix.gc = {
    automatic = true;
    frequency = "daily";
    options = "--delete-older-than 7d";
  };

  home = {
    username = primaryUser;
    stateVersion = "25.05";
    sessionVariables = {
      # shared environment variables
    };

    # create .hushlogin file to suppress login messages
    file.".hushlogin".text = "";

    # Symlink Nix GUI apps to ~/Applications so Spotlight/Alfred finds them
    activation.linkNixApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      app_folder="$HOME/Applications/Home Manager Apps"
      mkdir -p "$app_folder"
      find "$genProfilePath/home-path/Applications" -name "*.app" -maxdepth 1 -print0 2>/dev/null | while IFS= read -r -d "" app; do
        app_name=$(basename "$app")
        $DRY_RUN_CMD ln -sf "$app" "$app_folder/$app_name"
      done
    '';
  };
}
