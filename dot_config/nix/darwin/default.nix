{
  pkgs,
  inputs,
  self,
  primaryUser,
  systemNixpkgs,
  systemHomeManager,
  ...
}:
{
  imports = [
    ./local-dev.nix
    ./homebrew.nix
    ./nix-store-fallback.nix
    ./performance.nix
    # ./postgres.nix — demoted: not a base default. A host that wants an
    # always-on global PostgreSQL server imports it from its host module
    # (see hosts/bearcat). Projects with version-specific needs run their own
    # (mise .tool-versions / devenv / flake). The base ships only the psql
    # client (common/packages.nix).
    ./settings.nix
    systemHomeManager.darwinModules.home-manager
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

    # Route ambient `nixpkgs` (flake registry + <nixpkgs>/NIX_PATH) to the same
    # source the system builds against. Per-host: bearcat -> 26.05-darwin,
    # blackbird -> unstable. Without this, tools like devenv resolve
    # `flake:nixpkgs` from the user registry / channel default, which on
    # x86_64-darwin lands on unstable (26.11) and throws. `systemNixpkgs` is
    # passed in via specialArgs from `mkDarwin` in flake.nix.
    registry.nixpkgs.flake = systemNixpkgs;
    nixPath = [ "nixpkgs=${systemNixpkgs}" ];
  };

  # `nixpkgs.config` / `nixpkgs.overlays` live in `mkPkgs` in flake.nix, not
  # here: we pass `pkgs` directly to `darwin.lib.darwinSystem`, and that path
  # bypasses module-level nixpkgs configuration. Bake overlays / config at
  # import time in flake.nix; keep this module free of nixpkgs.* settings.

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
