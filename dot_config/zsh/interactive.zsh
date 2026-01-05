# Interactive shell setup
# Sourced from zshrc - collects widgets, keybindings, and other interactive bits

###########################################
# ZLE Widgets
###########################################

zmodload -i zsh/parameter

# Insert output of last command at cursor (Ctrl-x Ctrl-l)
insert-last-command-output() {
  LBUFFER+="$(eval $history[$((HISTCMD-1))])"
}

zle -N insert-last-command-output
bindkey "^X^L" insert-last-command-output

###########################################
# Starship prompt hooks
###########################################

# Track last command for starship custom.last_command module
_starship_command_run=0

starship_last_command_preexec() {
  export STARSHIP_LAST_COMMAND="$1"
  _starship_command_run=1
}

starship_last_command_precmd() {
  # If no command was run (just pressed Enter), clear last command
  if (( _starship_command_run == 0 )); then
    export STARSHIP_LAST_COMMAND=""
  fi
  _starship_command_run=0
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec starship_last_command_preexec
add-zsh-hook precmd starship_last_command_precmd

###########################################
# Keybinding utilities (optional)
###########################################

# Source keybindings.zsh for ztrace_*, show_keybindings, bindkey_dump
# Uncomment if you want these available in every shell:
# source $ZDOTDIR/support/keybindings.zsh
