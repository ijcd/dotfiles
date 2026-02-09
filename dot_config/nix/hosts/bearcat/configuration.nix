{
  pkgs,
  primaryUser,
  ...
}:
{
  networking.hostName = "bearcat";

  # host-specific homebrew (workarounds, experiments)
  homebrew.brews = [
    "mise"             # version manager (nix version broken on x86_64-darwin, nixpkgs#427748)
  ];

  # host-specific home-manager configuration
  home-manager.users.${primaryUser} = {
    home.packages = with pkgs; [
      graphite-cli
    ];

    programs = {
      zsh = {
        initContent = ''
          # Source shell functions
          source ${./shell-functions.sh}
        '';
      };
    };
  };
}
