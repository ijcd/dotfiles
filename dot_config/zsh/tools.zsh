debug_file_start

# Tool initialization - conditional hooks for CLI tools
# These check if the tool exists AND if it hasn't already been initialized
# (e.g., by Home Manager), to avoid double-init.

# direnv - auto-load .envrc files
if (( $+commands[direnv] )) && ! (( $+functions[_direnv_hook] )); then
  eval "$(direnv hook zsh)"
fi

# zoxide - smart cd
if (( $+commands[zoxide] )) && ! (( $+functions[__zoxide_z] )); then
  eval "$(zoxide init zsh)"
fi

# starship - prompt
if (( $+commands[starship] )) && [[ -z "$STARSHIP_SESSION_KEY" ]]; then
  eval "$(starship init zsh)"
fi

# fzf - fuzzy finder key bindings and completion
if (( $+commands[fzf] )) && ! (( $+functions[fzf-history-widget] )); then
  eval "$(fzf --zsh 2>/dev/null)" || {
    # Fallback for older fzf versions
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
  }
fi

# kubectl - kubernetes CLI completion
if (( $+commands[kubectl] )) && ! (( $+functions[_kubectl] )); then
  source <(kubectl completion zsh)
fi

# dotnet - global tools path
if (( $+commands[dotnet] )) && [[ -d ~/.dotnet/tools ]]; then
  path+=(~/.dotnet/tools)
fi

debug_file_end
