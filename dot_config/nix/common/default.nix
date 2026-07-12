{ primaryUser, lib, config, pkgs, ... }:
{
  imports = [
    ./packages.nix
    ./git.nix
    ./shell.nix
    ./mise.nix
    ./direnv.nix
    ./emacs.nix
    ./workspace.nix
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

    # kitty.terminfo (packages.nix) lands in the nix PROFILE terminfo dir, which
    # ncurses only finds via $TERMINFO_DIRS — and Home Manager exports that in
    # hm-session-vars.sh, TOO LATE for the login shell's terminfo init over ssh
    # (fails → "can't find terminal definition for xterm-kitty" → zsh ZLE inits
    # degraded → double echo). ~/.terminfo is searched FIRST, unconditionally, no
    # env var needed. Symlink the compiled entries there so login-time lookup
    # resolves xterm-kitty before any profile script runs.
    file.".terminfo" = {
      source = "${pkgs.kitty.terminfo}/share/terminfo";
      recursive = true;
    };
  };
}
