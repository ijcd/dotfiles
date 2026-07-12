{ pkgs, inputs, ... }:
{
  home = {
    packages = with pkgs; [
      # ─────────────────────────────────────────────────────────────────────────
      # Core CLI tools
      # ─────────────────────────────────────────────────────────────────────────
      coreutils          # GNU core utilities
      curl
      wget
      rsync
      tree
      eza                # modern ls replacement (used by chpwd hook)
      htop
      pstree             # process tree viewer
      watch
      jq                 # JSON processor

      # ─────────────────────────────────────────────────────────────────────────
      # Search & navigation
      # ─────────────────────────────────────────────────────────────────────────
      ripgrep            # fast grep
      fd                 # fast find
      fzf                # fuzzy finder
      fdupes             # duplicate file finder
      zoxide             # smart cd

      # ─────────────────────────────────────────────────────────────────────────
      # Editors & terminal
      # ─────────────────────────────────────────────────────────────────────────
      vim
      tmux
      kitty.terminfo     # xterm-kitty terminfo ONLY (no GUI) — so incoming ssh
                         # sessions from a kitty client resolve $TERM. The kitty
                         # app is the Homebrew cask (cask-groups.nix); its terminfo
                         # is trapped in the app bundle, invisible to sshd. Both
                         # hosts are ssh targets (see docs/runbooks/tailscale.md).
      # nodejs moved to emacs.nix (it's copilot.el's LSP dep, not a runtime).
      # Project node versions come from .tool-versions via mise.

      # ─────────────────────────────────────────────────────────────────────────
      # Git & version control
      # ─────────────────────────────────────────────────────────────────────────
      git
      gh                 # GitHub CLI
      delta              # better git diffs
      git-filter-repo    # history rewriting
      jujutsu            # jj: git-compatible VCS (config via chezmoi ~/.config/jj)
      git-branchless     # smartlog + `git undo`; run `git branchless init` per repo
      # jj-spr: stacked GitHub PRs for jj (flake input; not in nixpkgs). Skip the
      # upstream test suite: 2 config tests shell out to the `jj` binary + write a
      # config, neither of which exists in nix's hermetic build sandbox, so they
      # fail there. The binary builds fine (buildPhase + 66/68 tests pass).
      (inputs.jj-spr.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
        doCheck = false;
      }))

      # ─────────────────────────────────────────────────────────────────────────
      # Dev environment
      # ─────────────────────────────────────────────────────────────────────────
      # direnv - managed by programs.direnv in direnv.nix
      # mise - managed by homebrew (nix version broken on x86_64-darwin)
      chezmoi            # dotfile manager
      mkcert             # local HTTPS certs
      # watchman - file watcher (folly broken on x86_64-darwin, nixpkgs .align 64 asm error)

      # ─────────────────────────────────────────────────────────────────────────
      # Cloud & infrastructure
      # ─────────────────────────────────────────────────────────────────────────
      awscli2            # AWS CLI v2
      aws-vault          # AWS credential management
      doctl              # DigitalOcean CLI
      # flyctl - installed via curl (https://fly.io/install.sh), self-updates; nix lags behind
      kubectl            # Kubernetes CLI
      ansible            # Automation/orchestration

      # ─────────────────────────────────────────────────────────────────────────
      # Databases
      # ─────────────────────────────────────────────────────────────────────────
      postgresql_18      # psql/pg_dump CLIENT only — no global server here;
                         # projects run their own server (mise/devenv/flake).
                         # Bump major to track latest.
      mysql84            # MySQL 8.4
      sqlite             # SQLite

      # ─────────────────────────────────────────────────────────────────────────
      # Build tools & compilers
      # ─────────────────────────────────────────────────────────────────────────
      cmake
      readline

      # ─────────────────────────────────────────────────────────────────────────
      # Network tools
      # ─────────────────────────────────────────────────────────────────────────
      nmap               # network scanner
      mtr                # traceroute + ping
      mosh               # resilient SSH replacement (UDP, roams networks); server side ships mosh-server

      # ─────────────────────────────────────────────────────────────────────────
      # Process managers
      # ─────────────────────────────────────────────────────────────────────────
      overmind           # Procfile manager
      hivemind           # Procfile runner
      pm2                # Node.js process manager (used by cortextos)

      # ─────────────────────────────────────────────────────────────────────────
      # Media & graphics
      # ─────────────────────────────────────────────────────────────────────────
      imagemagick        # image manipulation
      ffmpeg             # video/audio processing
      yt-dlp             # youtube downloader
      mpv                # media player (audio/video)
      sox                # audio processing
      whisper-cpp        # speech-to-text (used by cortextos for voice messages)
      graphviz           # graph visualization
      poppler-utils      # PDF utilities
      tesseract          # OCR engine
      ocrmypdf           # add OCR text layer to scanned PDFs

      # ─────────────────────────────────────────────────────────────────────────
      # Nix tooling
      # ─────────────────────────────────────────────────────────────────────────
      devenv             # reproducible dev environments
      nil                # Nix LSP
      nixfmt             # Nix formatter
      nvd                # Nix version diff (compare system generations)

      # ─────────────────────────────────────────────────────────────────────────
      # Other dev tools
      # ─────────────────────────────────────────────────────────────────────────
      biome              # JS/TS linter/formatter
      exercism           # coding exercises
      vbindiff           # binary diff viewer
      keychain           # SSH agent helper

      # ─────────────────────────────────────────────────────────────────────────
      # Fun / Shell greeting
      # ─────────────────────────────────────────────────────────────────────────
      fortune                # random quotes/jokes
      cowsay                 # ASCII art speech bubbles
      lolcat                 # rainbow text

      # ─────────────────────────────────────────────────────────────────────────
      # Fonts
      # ─────────────────────────────────────────────────────────────────────────
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
    ];
  };
}
