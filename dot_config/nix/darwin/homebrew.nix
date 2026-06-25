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
      cleanup = "uninstall";         # one of "none", "uninstall", "zap"
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
