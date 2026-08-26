{
  description = "My system configuration";
  inputs = {
    # monorepo w/ recipes ("derivations") — top-level default is unstable.
    # Used by aarch64-darwin hosts (blackbird) and every other system.
    # Intel (x86_64-darwin, bearcat) is routed to `nixpkgs-bearcat` below —
    # nixpkgs ≥26.11 hard-dropped x86_64-darwin (a `throw`, not a warning).
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # ── bearcat / x86_64-darwin: pinned to the 26.05 release track ──
    # nixpkgs ≥26.11 hard-dropped x86_64-darwin (last supporting release is
    # 26.05, security fixes through ~end of 2026). nix-darwin asserts its
    # branch matches nixpkgs' branch, so pin all three (nixpkgs, nix-darwin,
    # home-manager) to the 26.05 line for bearcat. jj-spr also follows
    # `nixpkgs-bearcat` (see its input below).
    nixpkgs-bearcat.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    darwin-bearcat.url = "github:lnl7/nix-darwin/nix-darwin-26.05";
    darwin-bearcat.inputs.nixpkgs.follows = "nixpkgs-bearcat";
    home-manager-bearcat.url = "github:nix-community/home-manager/release-26.05";
    home-manager-bearcat.inputs.nixpkgs.follows = "nixpkgs-bearcat";

    # ── blackbird / aarch64-darwin: unstable track ──
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

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
    # Follows `nixpkgs-bearcat` (26.05-darwin) so jj-spr's own flake eval
    # survives on x86_64-darwin. blackbird's jj-spr also builds against 26.05,
    # which is fine — it's a small stable tool.
    jj-spr.url = "github:jennings/jj-spr";
    jj-spr.inputs.nixpkgs.follows = "nixpkgs-bearcat";

  };

  outputs =
    {
      self,
      nixpkgs,
      nix-homebrew,
      ...
    }@inputs:
    let
      primaryUser = "ijcd";

      # Route each host's system tools per release track. x86_64-darwin ->
      # pinned 26.05 (nixpkgs, nix-darwin, home-manager all on the 26.05
      # release line; last release supporting Intel Mac). Everything else ->
      # unstable / master. nix-darwin's own assertion forbids mixing branches,
      # so all three route together.
      nixpkgsFor = system:
        if system == "x86_64-darwin" then inputs.nixpkgs-bearcat
        else inputs.nixpkgs;
      darwinFor = system:
        if system == "x86_64-darwin" then inputs.darwin-bearcat
        else inputs.darwin;
      homeManagerFor = system:
        if system == "x86_64-darwin" then inputs.home-manager-bearcat
        else inputs.home-manager;

      # Build a per-system pkgs set with our overlays baked in. Overlays live
      # here (not in a module's `nixpkgs.overlays`) because we pass `pkgs`
      # directly to `darwin.lib.darwinSystem` — that path bypasses module-level
      # overlay configuration, so we bake overlays in at import time.
      mkPkgs = system:
        import (nixpkgsFor system) {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            inputs.emacs-overlay.overlay
            # See nixpkgs-bash52 input comment above for the bash 5.3 heredoc
            # deadlock context.
            (final: prev:
              let
                # Fresh minimal config: prev.config carries replaceStdenv=null
                # from unstable nixpkgs, which the pinned (Jul-2025) nixpkgs
                # calls as a function without an isFunction guard -> eval error.
                pkgs-bash52 = import inputs.nixpkgs-bash52 {
                  inherit (prev.stdenv.hostPlatform) system;
                  config = { allowUnfree = true; };
                };
              in
              {
                # Only override the interactive bash. bashNonInteractive feeds
                # the darwin stdenv bootstrap (allDeps
                # isBuiltByBootstrapFilesCompiler assertion); overriding it
                # with a foreign-built bash breaks the bootstrap chain.
                #
                # nixos-25.05 channel has bash 5.2 fully cached on
                # cache.nixos.org — wholesale import is fast (fetches binary,
                # ~2.5 MiB) and doesn't rely on the build env's bash working
                # (which it doesn't, since that's the bug we're working around
                # in the first place).
                bashInteractive = pkgs-bash52.bashInteractive;
              })
          ];
        };

      # Every host is the shared ./darwin config plus an OPTIONAL thin host
      # module. ./darwin alone already yields a working system (packages,
      # homebrew, macOS defaults, full Home Manager). A host module is ONLY for
      # corner-case overrides (hostname, per-machine fixes).
      mkDarwin =
        { system, hostModule ? null }:
        (darwinFor system).lib.darwinSystem {
          inherit system;
          pkgs = mkPkgs system;
          modules = [ ./darwin ] ++ nixpkgs.lib.optional (hostModule != null) hostModule;
          specialArgs = {
            inherit inputs self primaryUser;
            # Per-system nixpkgs source. `darwin/default.nix` uses this to
            # route `nix.registry.nixpkgs` and `nix.nixPath` at the same
            # source the system builds against, so ambient `nixpkgs`
            # (devenv, `<nixpkgs>`, `flake:nixpkgs`) resolves to it too.
            systemNixpkgs = nixpkgsFor system;
            # Per-system home-manager (must match nix-darwin's release
            # branch — see the input comment above). `darwin/default.nix`
            # imports `systemHomeManager.darwinModules.home-manager`.
            systemHomeManager = homeManagerFor system;
          };
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
