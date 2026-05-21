{
  pkgs,
  inputs,
  self,
  primaryUser,
  ...
}:
{
  imports = [
    ./local-dev.nix
    ./homebrew.nix
    ./nix-store-fallback.nix
    ./performance.nix
    ./postgres.nix
    ./settings.nix
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  # nix config
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # disabled due to https://github.com/NixOS/nix/issues/7273
      # auto-optimise-store = true;

      # devenv/cachix binary caches
      extra-substituters = [
        "https://devenv.cachix.org"
        "https://cachix.cachix.org"
      ];
      extra-trusted-public-keys = [
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      ];
    };
    enable = false; # nix installed separately, don't let nix-darwin manage it
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    inputs.emacs-overlay.overlay
    # See nixpkgs-bash52 input comment in flake.nix.
    (final: prev:
      let
        # Fresh minimal config: prev.config carries replaceStdenv=null from
        # current unstable nixpkgs, which the pinned (Jul-2025) nixpkgs calls
        # as a function without an isFunction guard -> eval error.
        pkgs-bash52 = import inputs.nixpkgs-bash52 {
          inherit (prev.stdenv.hostPlatform) system;
          config = { allowUnfree = true; };
        };
      in
      {
        # Only override the interactive bash. bashNonInteractive feeds the
        # darwin stdenv bootstrap (allDeps isBuiltByBootstrapFilesCompiler
        # assertion); overriding it with a foreign-built bash breaks the
        # bootstrap chain.
        #
        # nixos-25.05 channel has bash 5.2 fully cached on cache.nixos.org —
        # wholesale import is fast (fetches binary, ~2.5 MiB) and doesn't
        # rely on the build env's bash working (which it doesn't, since
        # that's the bug we're working around in the first place).
        bashInteractive = pkgs-bash52.bashInteractive;
      })
  ];

  # homebrew installation manager
  nix-homebrew = {
    user = primaryUser;
    enable = true;
    autoMigrate = true;
  };

  # home-manager config
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "mine";
    users.${primaryUser} = {
      imports = [
        ../common
      ];
    };
    extraSpecialArgs = {
      inherit inputs self primaryUser;
    };
  };

  # System zsh config (completion handled by Zim)
  programs.zsh = {
    enable = true;
    enableCompletion = false;
    enableBashCompletion = false;
    promptInit = "";  # Disable default prompt, using starship
  };

  # macOS-specific settings
  system.primaryUser = primaryUser;
  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
    shell = pkgs.zsh;
  };
  environment = {
    systemPath = [
      "/opt/homebrew/bin"
    ];
    pathsToLink = [ "/Applications" ];
  };
}
