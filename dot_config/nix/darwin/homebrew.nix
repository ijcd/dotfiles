{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;             # fetch latest formulae/casks
      upgrade = true;                # upgrade outdated packages
      extraFlags = [ "--greedy" ];   # upgrade casks even if version unchanged
      cleanup = "uninstall";         # one of "none", "uninstall", "zap"
    };

    caskArgs.no_quarantine = true;
    global.brewfile = true;

    # homebrew is best for GUI apps
    # nixpkgs is best for CLI tools
    casks = [
    ];
    brews = [
    ];
    taps = [
    ];
  };
}
