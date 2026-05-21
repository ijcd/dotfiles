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

    # emacs packages (emacs-pgtk for Wayland, daily MELPA snapshots)
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";

    # declarative homebrew management
    # TODO: pin homebrew taps (https://blog.dbalan.in/blog/2024/03/25/boostrap-a-macos-machine-with-nix/index.html?utm_source=chatgpt.com)
    # NOTE 2026-05-09: brew-src override to upstream master; remove once
    # zhaofengli/nix-homebrew #136 (5.1.10 bump) merges. Tracks #138 fix.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-homebrew.inputs.brew-src.url = "github:Homebrew/brew/master";

    # Pin bash to 5.2 to avoid bash 5.3 heredoc deadlock on macOS:
    # 5.3 switched to pipe-based heredocs; macOS pipes block at ~512 B with no
    # reader, so `cat > file <<EOF` with bodies > 512 B hangs (e.g. nix-direnv's
    # _nix_direnv_preflight). Pinned to nixos-25.05 channel because channel
    # commits have full cache.nixos.org coverage — bash 5.2 fetches as binary
    # (~2.5 MiB) instead of compiling from source. Remove once upstream bash
    # fixes the heredoc bug.
    nixpkgs-bash52.url = "github:nixos/nixpkgs/nixos-25.05";

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
