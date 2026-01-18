debug_file_start

# ─────────────────────────────────────────────────────────────────────────────
# Tool initialization - conditional hooks for CLI tools
# ─────────────────────────────────────────────────────────────────────────────
# These run shell hooks for various tools. Each checks:
#   1. Is the tool installed?
#   2. Has it already been initialized (e.g., by Home Manager)?
# This allows the same dotfiles to work with or without Home Manager.

# direnv - automatically load/unload .envrc files when entering directories
# Useful for per-project environment variables (API keys, PATH modifications)
# https://direnv.net
if (( $+commands[direnv] )) && ! (( $+functions[_direnv_hook] )); then
  eval "$(direnv hook zsh)"
fi

# zoxide - smarter cd that learns your habits ("z foo" jumps to ~/projects/foo)
# Replaces autojump/z/fasd
# https://github.com/ajeetdsouza/zoxide
if (( $+commands[zoxide] )) && ! (( $+functions[__zoxide_z] )); then
  eval "$(zoxide init zsh)"
fi

# j - wrapper for zi (interactive zoxide) with tab completion
# Gives fasd-like UX: j foo<TAB> completes from db, j foo<ENTER> opens fzf
function j() {
    zi "$@"
}

# Tab completion for zoxide commands - completes from frecency database
# instead of local dirs (why use z/zi if you want cd-style completion?)
function _zoxide_complete() {
    # Only complete when cursor is at end of line
    [[ "${#words[@]}" -eq "${CURRENT}" ]] || return 0

    local -a dirs expl
    # Query zoxide db - works with or without args (empty args = all entries)
    dirs=(${(f)"$(zoxide query -l -- ${words[2,-1]} 2>/dev/null | head -15)"})

    if (( ${#dirs} )); then
        # Force menu selection (no common-prefix completion)
        compstate[insert]=menu
        compstate[list]=list
        # -M '': ignore global matcher-list styles
        # -U: don't filter (zoxide already did)
        # -o nosort: preserve frecency order
        _wanted directories expl 'zoxide' compadd -M '' -U -o nosort -a dirs
    fi
}
compdef _zoxide_complete j z zi

# starship - fast, customizable prompt written in Rust
# Config lives at ~/.config/starship.toml
# https://starship.rs
if (( $+commands[starship] )) && [[ -z "$STARSHIP_SESSION_KEY" ]]; then
  eval "$(starship init zsh)"
fi

# fzf - fuzzy finder for files, history, etc.
# Adds: Ctrl+R (history), Ctrl+T (files), Alt+C (cd)
# https://github.com/junegunn/fzf
if (( $+commands[fzf] )) && ! (( $+functions[fzf-history-widget] )); then
  eval "$(fzf --zsh 2>/dev/null)" || {
    # Fallback for older fzf versions that don't have --zsh
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
  }
fi

# ─────────────────────────────────────────────────────────────────────────────
# Shell completions for CLI tools
# ─────────────────────────────────────────────────────────────────────────────

# kubectl - Kubernetes CLI
# Adds tab completion for kubectl commands, resources, namespaces, etc.
if (( $+commands[kubectl] )) && ! (( $+functions[_kubectl] )); then
  source <(kubectl completion zsh)
fi

# kops - Kubernetes Operations (cluster provisioning on AWS)
# Only useful if you create/manage K8s clusters on AWS
if (( $+commands[kops] )) && ! (( $+functions[_kops] )); then
  source <(kops completion zsh)
fi

# ─────────────────────────────────────────────────────────────────────────────
# PATH additions for language-specific tool directories
# ─────────────────────────────────────────────────────────────────────────────
# These are where language toolchains install user binaries.
# The toolchain itself may come from nix/mise, but user-installed
# packages (e.g., "cargo install", "dotnet tool install -g") go here.

# dotnet - .NET global tools (e.g., dotnet-ef, dotnet-outdated)
# Installed via: dotnet tool install -g <tool>
if (( $+commands[dotnet] )) && [[ -d ~/.dotnet/tools ]]; then
  path+=(~/.dotnet/tools)
fi

# rust/cargo - Cargo-installed binaries (e.g., cargo-watch, ripgrep if installed via cargo)
# Installed via: cargo install <crate>
if [[ -d ~/.cargo/bin ]]; then
  path+=(~/.cargo/bin)
fi

debug_file_end
