{ config, ... }: {
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
  # mkOutOfStoreSymlink = target is mutable (HM does not manage its contents).
  # The .zshenv entry is the existing "don't manage this, chezmoi owns it" guard.
  home.file = let
    relocate = target: {
      source = config.lib.file.mkOutOfStoreSymlink target;
    };
  in {
    ".zshenv".enable = false;   # chezmoi manages ~/.zshenv as a symlink

    ".vscode"        = relocate "${config.home.homeDirectory}/.local/share/vscode";
    ".vscode-shared" = relocate "${config.home.homeDirectory}/.local/share/vscode-shared";
    ".cursor"        = relocate "${config.home.homeDirectory}/.local/share/cursor";
    ".pgadmin"       = relocate "${config.home.homeDirectory}/.local/share/pgadmin";
    ".copilot"       = relocate "${config.home.homeDirectory}/.local/share/copilot";
    ".sobelow"       = relocate "${config.home.homeDirectory}/.local/share/sobelow";
    ".orbstack"      = relocate "${config.home.homeDirectory}/.local/share/orbstack";
    ".ollama"        = relocate "${config.home.homeDirectory}/.local/share/ollama";
    ".claude.json"   = relocate "${config.home.homeDirectory}/.local/share/claude/claude.json";
  };

  # Bash: only used by stray scripts on this machine, but redirect HISTFILE so
  # any interactive bash session writes XDG-style.
  programs.bash = {
    enable = true;
    historyFile = "${config.home.homeDirectory}/.local/state/bash/history";
  };
}
