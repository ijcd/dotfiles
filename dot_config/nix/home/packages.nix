{ pkgs, ... }:
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

      # ─────────────────────────────────────────────────────────────────────────
      # Git & version control
      # ─────────────────────────────────────────────────────────────────────────
      git
      gh                 # GitHub CLI
      delta              # better git diffs
      git-filter-repo    # history rewriting

      # ─────────────────────────────────────────────────────────────────────────
      # Dev environment
      # ─────────────────────────────────────────────────────────────────────────
      # direnv - managed by programs.direnv in direnv.nix
      mise               # polyglot version manager (node, rust, python, etc.)
      chezmoi            # dotfile manager
      mkcert             # local HTTPS certs
      watchman           # file watcher

      # ─────────────────────────────────────────────────────────────────────────
      # Cloud & infrastructure
      # ─────────────────────────────────────────────────────────────────────────
      awscli2            # AWS CLI v2
      aws-vault          # AWS credential management
      doctl              # DigitalOcean CLI
      flyctl             # Fly.io CLI
      pulumi-bin         # Infrastructure as code
      kubectl            # Kubernetes CLI
      ansible            # Automation/orchestration

      # ─────────────────────────────────────────────────────────────────────────
      # Databases
      # ─────────────────────────────────────────────────────────────────────────
      postgresql_17      # PostgreSQL 17
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

      # ─────────────────────────────────────────────────────────────────────────
      # Process managers
      # ─────────────────────────────────────────────────────────────────────────
      overmind           # Procfile manager
      hivemind           # Procfile runner

      # ─────────────────────────────────────────────────────────────────────────
      # Media & graphics
      # ─────────────────────────────────────────────────────────────────────────
      imagemagick        # image manipulation
      ffmpeg             # video/audio processing
      yt-dlp             # youtube downloader
      sox                # audio processing
      graphviz           # graph visualization
      poppler_utils      # PDF utilities

      # ─────────────────────────────────────────────────────────────────────────
      # Nix tooling
      # ─────────────────────────────────────────────────────────────────────────
      devenv             # reproducible dev environments
      nil                # Nix LSP
      nixfmt-rfc-style   # Nix formatter
      nvd                # Nix version diff (compare system generations)

      # ─────────────────────────────────────────────────────────────────────────
      # Other dev tools
      # ─────────────────────────────────────────────────────────────────────────
      biome              # JS/TS linter/formatter
      exercism           # coding exercises
      vbindiff           # binary diff viewer
      keychain           # SSH agent helper

      # ─────────────────────────────────────────────────────────────────────────
      # AI & LLMs
      # ─────────────────────────────────────────────────────────────────────────
      ollama             # local LLMs

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
