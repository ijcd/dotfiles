{ ... }:
let
  groups = import ./cask-groups.nix;
in
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;            # skip `brew update` on rebuild; run manually
      upgrade = false;               # skip `brew upgrade` on rebuild; run manually
      # "none" — do NOT clean up on every switch. brew 6.0 deprecated the
      # activation `--cleanup` switch (it now dry-runs + interactively prompts
      # every run and never completes). Periodic cleanup is handled on a cadence
      # by nixhome-rebuild instead (`brew bundle cleanup` every ~7 days).
      cleanup = "none";              # one of "none", "uninstall", "zap"
      extraFlags = [ "--verbose" ];  # stream per-package progress during `darwin-rebuild switch`
    };

    # caskArgs.no_quarantine removed in newer Homebrew
    global.brewfile = true;

    # homebrew is best for GUI apps
    # nixpkgs is best for CLI tools

    taps = [
      "nikitabobko/tap" # for aerospace
      "raine/workmux" # for workmux (brews list references raine/workmux/workmux)
    ];

    brews = [
      # ─────────────────────────────────────────────────────────────────────────
      # Native-build toolchain — leaf deps for compiling tools via mise/asdf
      # (postgres, erlang, etc.). MUST be brew, not nix: mise's postgres plugin
      # probes Homebrew paths (/opt/homebrew/opt/{openssl@3,icu4c}). Not runtimes
      # themselves — just the libs/tools source builds link against.
      # ─────────────────────────────────────────────────────────────────────────
      "pkg-config"       # configure scripts need it (postgres build fails without)
      "icu4c"            # postgres ICU support (icu-uc/icu-i18n)
      "openssl@3"        # TLS for postgres/erlang source builds
      "gnupg"            # gpg — node/asdf plugin key verification

      # ─────────────────────────────────────────────────────────────────────────
      # Docker (better via brew on macOS for socket/VM integration)
      # ─────────────────────────────────────────────────────────────────────────
      "docker"
      "colima"

      # ─────────────────────────────────────────────────────────────────────────
      # macOS-specific tools
      # ─────────────────────────────────────────────────────────────────────────
      "mas"              # Mac App Store CLI

      # ─────────────────────────────────────────────────────────────────────────
      # Tools not in nixpkgs (or brew version preferred)
      # ─────────────────────────────────────────────────────────────────────────
      "git-subrepo"      # subtree/subrepo workflows
      "gdrive"           # Google Drive CLI; used for business ops + exports
      "ibazel"           # Bazel file watcher
      "aws-sso-cli"      # AWS SSO helper
      "aws-sso-util"     # AWS SSO utilities
      "mise"             # version manager (nix broken on x86_64-darwin, nixpkgs#427748)
      "raine/workmux/workmux" # tmux workspace manager (nix flake needs rust 1.88+)
      "rtk"              # LLM token compressor — proxies Claude Code Bash output (rtk-ai/rtk; not in nixpkgs)
      "eask-cli"         # Emacs Lisp project build tool (emacs-eask.github.io; binary is `eask`)
      "lefthook"         # git hook manager — config in repo-root lefthook.yml; run `lefthook install` per clone
      "mkcert"           # locally-trusted dev TLS certs (local CA + leaf certs); `mkcert -install`
    ];

    # Universal cask set — installed on EVERY host, including the generic
    # per-arch fallbacks. Hosts add their own groups in
    # hosts/<host>/configuration.nix (nix-darwin concatenates the lists).
    # Group definitions live in ./cask-groups.nix.
    casks = with groups;
      base
      ++ terminals
      ++ editors
      ++ ai
      ++ dev
      ++ windowMgmt
      ++ workComms
      ++ browsers
      ++ notes;
  };
}
