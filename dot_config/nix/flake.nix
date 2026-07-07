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

    # jj-spr: submit Jujutsu changes as GitHub stacked PRs (not in nixpkgs).
    # Upstream flake exposes packages.<system>.default; follow our nixpkgs so it
    # builds against the same tree (no second nixpkgs eval).
    jj-spr.url = "github:jennings/jj-spr";
    jj-spr.inputs.nixpkgs.follows = "nixpkgs";

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
      primaryUser = "ijcd";

      # Every host is the shared ./darwin config plus an OPTIONAL thin host
      # module. ./darwin alone already yields a working system (packages,
      # homebrew, macOS defaults, full Home Manager). A host module is ONLY for
      # corner-case overrides (hostname, per-machine fixes).
      mkDarwin =
        { system, hostModule ? null }:
        darwin.lib.darwinSystem {
          inherit system;
          modules = [ ./darwin ] ++ nixpkgs.lib.optional (hostModule != null) hostModule;
          specialArgs = { inherit inputs self primaryUser; };
        };

      # Named hosts — add an entry here only when a machine needs overrides.
      namedHosts = {
        bearcat = {
          system = "x86_64-darwin";
          hostModule = ./hosts/bearcat/configuration.nix;
        }; # Intel home desktop
        blackbird = {
          system = "aarch64-darwin";
          hostModule = ./hosts/blackbird/configuration.nix;
        }; # Apple Silicon work laptop
      };

      # Generic per-arch fallbacks — a brand-new machine bootstraps straight
      # from ./darwin with NO custom config:
      #   sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#aarch64-darwin   # Apple Silicon
      #   sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#x86_64-darwin    # Intel
      # Graduate to a named host later only if it needs corner-case fixes.
      fallbackHosts = {
        aarch64-darwin = { system = "aarch64-darwin"; };
        x86_64-darwin = { system = "x86_64-darwin"; };
        # `.#default` = guaranteed working base for an unnamed machine. Bound to
        # Apple Silicon (every new Mac); on Intel use `.#x86_64-darwin`. The
        # bootstrap resolver (scripts/bootstrap.sh) auto-picks the right one.
        default = { system = "aarch64-darwin"; };
      };
    in
    {
      # build darwin flake using:
      # $ darwin-rebuild build --flake .#<name>
      darwinConfigurations = nixpkgs.lib.mapAttrs (_: mkDarwin) (namedHosts // fallbackHosts);
    };
}
