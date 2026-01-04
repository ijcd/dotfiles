{
  description = "My system configuration";
  inputs = {
    # monorepo w/ recipes ("derivations")
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # manages configs
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # system-level software and settings (macOS)
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # declarative homebrew management
    # TODO: pin homebrew taps (https://blog.dbalan.in/blog/2024/03/25/boostrap-a-macos-machine-with-nix/index.html?utm_source=chatgpt.com)
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    {
      self,
      darwin,
      nixpkgs,
      home-manager,
      nix-homebrew,
      ...
    }@inputs:
    let
      # TODO: replace with your username
      primaryUser = "ijcd";
    in
    {
      # build darwin flake using:
      # $ darwin-rebuild build --flake .#<name>
      darwinConfigurations."bearcat" = darwin.lib.darwinSystem {
        #system = "aarch64-darwin";
        system = "x86_64-darwin";
        modules = [
          ./darwin
          ./hosts/bearcat/configuration.nix
        ];
        specialArgs = { inherit inputs self primaryUser; };
      };
    };
}
