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
# Custom command browser (my-commands / my-help)
###########################################

# Load the my-help function
source $ZDOTDIR/functions/my-help
source $ZDOTDIR/functions/devshell
# runclaude is now a binary at ~/.local/bin/runclaude (so sesh/PATH-scanning
# session managers can see it). The old function lived at functions/runclaude.

# Ctrl+/ - Launch my-commands browser
zle -N _my-commands-widget
bindkey "^_" _my-commands-widget  # Ctrl+/ sends ^_

# Ctrl+? - Show quick help
zle -N _my-help-widget
bindkey "^[?" _my-help-widget  # Alt+? for help (Ctrl+Shift+/ on some terminals)

###########################################
# Keybinding utilities (optional)
###########################################

# Source keybindings.zsh for ztrace_*, show_keybindings, bindkey_dump
# Uncomment if you want these available in every shell:
# source $ZDOTDIR/support/keybindings.zsh

###########################################
# Directory-based terminal colors
###########################################

source $ZDOTDIR/functions/dircolor

_dircolor_chpwd() { dircolor apply }
add-zsh-hook chpwd _dircolor_chpwd
dircolor apply  # apply on shell start

###########################################
# Auto-listing on directory change
###########################################
# Show pwd + listing after every cd. Three tiers based on entry count:
#   <= 100        normal eza grid
#   101–500       abbreviated single-column head -20 with indicator
#   > 500         skipped with indicator
# Falls back to `ls` if eza isn't installed.
_ll_chpwd() {
  emulate -L zsh
  print -P "%F{75}%~%f"
  local n
  n=$(command ls -A1 2>/dev/null | wc -l | tr -d ' ')
  local lister="eza --group-directories-first --icons=auto"
  (( $+commands[eza] )) || lister="ls -A"
  if (( n == 0 )); then
    print -P "  %F{244}(empty)%f"
  elif (( n <= 100 )); then
    ${=lister}
  elif (( n <= 500 )); then
    print -P "  %F{220}⋯ showing 20 of $n%f %F{244}(\`eza\` for all)%f"
    if (( $+commands[eza] )); then
      eza -1 --group-directories-first --icons=auto | head -20
    else
      ls -A1 | head -20
    fi
  else
    print -P "  %F{203}⊘ $n entries — too many to list%f %F{244}(\`eza\` or \`ls\` to view)%f"
  fi
}
add-zsh-hook chpwd _ll_chpwd
