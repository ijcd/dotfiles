{ config, lib, ... }:
let
  homeDir = config.home.homeDirectory;

  # Tier 2 relocations: tools that hardcode $HOME/.foo. Out-of-store symlinks
  # so the real data lives in XDG paths but the tool still finds it where it
  # expects. mkOutOfStoreSymlink = target is mutable (HM does not manage its
  # contents). Single source of truth: this attrset drives BOTH the home.file
  # symlink entries AND the set of target dirs we ensure exist (below).
  # name (~/.foo) -> target the symlink points at.
  relocations = {
    ".vscode"        = "${homeDir}/.local/share/vscode";
    ".vscode-shared" = "${homeDir}/.local/share/vscode-shared";
    ".cursor"        = "${homeDir}/.local/share/cursor";
    ".pgadmin"       = "${homeDir}/.local/share/pgadmin";
    ".copilot"       = "${homeDir}/.local/share/copilot";
    ".sobelow"       = "${homeDir}/.local/share/sobelow";
    ".orbstack"      = "${homeDir}/.local/share/orbstack";
    ".ollama"        = "${homeDir}/.local/share/ollama";
    ".claude.json"   = "${homeDir}/.local/share/claude/claude.json";
  };

  # --- xdgManagedDirs: the full set of XDG dirs the config assumes exist. -----
  # Derived from the config itself (single source of truth) so that adding e.g.
  # CARGO_HOME to sessionVariables updates the list for free. Two consumers:
  #   1. home.activation.ensureXdgDirs  — mkdir -p on every rebuild (auto-heal)
  #   2. the xdg-dirs manifest          — read by the ~/.local/bin/xdg-dirs CLI

  # (1) From home.sessionVariables: a key ending _HOME/_DIR names a directory;
  #     a key ending FILE names a file, so its parent dir is what must exist.
  #     Only string values under $HOME are considered.
  sessionDirs = lib.filter (v: v != null && lib.hasPrefix homeDir v)
    (lib.mapAttrsToList (k: v:
      if !(builtins.isString v) then null
      else if lib.hasSuffix "_HOME" k || lib.hasSuffix "_DIR" k then v
      else if lib.hasSuffix "FILE" k then builtins.dirOf v
      else null
    ) config.home.sessionVariables);

  # (2) From the relocation targets: a dir target must exist as-is; a file
  #     target (e.g. .claude.json) must NOT be pre-created (mkdir over it would
  #     break the symlink) so we ensure its parent dir instead. A target is
  #     treated as a file when its basename contains a "." (e.g. claude.json).
  relocationDirs = lib.mapAttrsToList (_: target:
    if lib.hasInfix "." (builtins.baseNameOf target)
    then builtins.dirOf target
    else target
  ) relocations;

  # (3) extraDirs: things the derivation above can't see.
  extraDirs = [
    "${homeDir}/.local/state/zsh"           # HISTFILE set in dot_config/zsh/options.zsh (not nix)
    "${homeDir}/.local/state/bash"          # programs.bash.historyFile parent
    "${homeDir}/.local/share/cargo/bin"     # home.sessionPath entry
    "${homeDir}/.local/share/ollama/models" # OLLAMA_MODELS (suffix not matched above)
    config.programs.zsh.dotDir              # ~/.local/share/hm-zsh
  ];

  xdgManagedDirs = lib.unique
    (lib.filter (lib.hasPrefix homeDir) (sessionDirs ++ relocationDirs ++ extraDirs));
in
{
  # Zsh dotfiles managed by chezmoi (ZDOTDIR=~/.config/zsh)
  # HM generates its zshrc to a separate location, which we source for integrations
  # ~/.zshenv is a symlink managed by chezmoi, so HM doesn't touch it
  programs.zsh = {
    enable = true;
    # Absolute path — current home-manager DEPRECATED relative dotDir. HM writes
    # its integration zshrc here; ~/.config/zsh/.zshrc sources it (see zshrc).
    # (The cm-cd subshell prompt fix is the tools.zsh starship guard, not this.)
    dotDir = "${config.home.homeDirectory}/.local/share/hm-zsh";
    enableCompletion = false;  # Zim handles completion
  };

  # Starship prompt (config managed by chezmoi, init via HM's zshrc)
  programs.starship.enable = true;

  # Redirect noisy dotfiles out of $HOME — XDG-style placement.
  # Tier 1: tools that honor a dedicated env var.
  # Tier 2 (below): tools that hardcode $HOME/.foo; HM creates an
  # out-of-store symlink so the data actually lives elsewhere.
  home.sessionVariables = {
    # Process manager
    PM2_HOME                     = "${config.home.homeDirectory}/.local/share/pm2";

    # npm
    NPM_CONFIG_CACHE             = "${config.home.homeDirectory}/.cache/npm";
    NPM_CONFIG_USERCONFIG        = "${config.home.homeDirectory}/.config/npm/npmrc";

    # Rust toolchain
    CARGO_HOME                   = "${config.home.homeDirectory}/.local/share/cargo";
    RUSTUP_HOME                  = "${config.home.homeDirectory}/.local/share/rustup";

    # Containers
    DOCKER_CONFIG                = "${config.home.homeDirectory}/.config/docker";
    COLIMA_HOME                  = "${config.home.homeDirectory}/.config/colima";

    # Cloud
    AWS_CONFIG_FILE              = "${config.home.homeDirectory}/.config/aws/config";
    AWS_SHARED_CREDENTIALS_FILE  = "${config.home.homeDirectory}/.config/aws/credentials";
    PULUMI_HOME                  = "${config.home.homeDirectory}/.local/share/pulumi";
    FLY_HOME                     = "${config.home.homeDirectory}/.local/share/fly";

    # Elixir
    MIX_HOME                     = "${config.home.homeDirectory}/.local/share/mix";
    HEX_HOME                     = "${config.home.homeDirectory}/.local/share/hex";

    # AI / local models (whole ~/.ollama symlinked below; this still pins the models subdir)
    OLLAMA_MODELS                = "${config.home.homeDirectory}/.local/share/ollama/models";

    # devenv user-global cache (per-project state still goes in <project>/.devenv/)
    DEVENV_DOTFILE               = "${config.home.homeDirectory}/.local/share/devenv";

    # Secrets / creds
    LPASS_HOME                   = "${config.home.homeDirectory}/.cache/lpass";

    # REPL / pager histories
    LESSHISTFILE                 = "${config.home.homeDirectory}/.local/state/less/history";
    PYTHON_HISTORY               = "${config.home.homeDirectory}/.local/state/python/history";  # py 3.13+
    WGETRC                       = "${config.home.homeDirectory}/.config/wget/wgetrc";
  };

  # Add cargo-installed tools to PATH at new location.
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/share/cargo/bin"
  ];

  # Tier 2: tools that hardcode $HOME/.foo. Out-of-store symlinks so the
  # real data lives in XDG paths but the tool still finds it where it expects.
  # The .zshenv entry is the existing "don't manage this, chezmoi owns it" guard.
  # Symlink entries are generated from the `relocations` attrset above so the
  # dir-ensure logic and the symlinks never drift.
  home.file =
    {
      ".zshenv".enable = false;   # chezmoi manages ~/.zshenv as a symlink
    }
    // builtins.mapAttrs (_: target: {
      source = config.lib.file.mkOutOfStoreSymlink target;
    }) relocations
    // {
      # Manifest read by the ~/.local/bin/xdg-dirs CLI (one dir per line).
      # home.file creates the parent dir; keep in sync with ensureXdgDirs below.
      "${config.xdg.configHome}/xdg-dirs/manifest".text =
        lib.concatStringsSep "\n" xdgManagedDirs + "\n";
    };

  # Auto-heal: create every expected XDG dir on each `darwin-rebuild switch`.
  # Deliberately does NOT shell out to the xdg-dirs CLI — activation is
  # nix-owned and must run even if the CLI isn't on PATH yet.
  home.activation.ensureXdgDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatMapStringsSep "\n"
      (d: "$DRY_RUN_CMD mkdir -p ${lib.escapeShellArg d}")
      xdgManagedDirs
  );

  # Bash: only used by stray scripts on this machine, but redirect HISTFILE so
  # any interactive bash session writes XDG-style.
  programs.bash = {
    enable = true;
    historyFile = "${config.home.homeDirectory}/.local/state/bash/history";
  };
}
