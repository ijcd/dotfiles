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
# SSH remote-session indicator (peer-visible background tint)
###########################################
# When this shell is running as an incoming SSH session, paint a distinct
# background so nested hops (kitty → antares → bearcat → …) are obvious at
# a glance. Color derived from short-hostname hash — stable per host,
# distinct across hosts, no config table. Override with $SSH_TINT_HEX
# (e.g. 1e3a5f) if the auto color is bad.
#
# Trades vs dircolor: dircolor picks a color per DIRECTORY (local only,
# see functions/dircolor SSH short-circuit); this picks a color per HOST
# (remote only). One or the other paints, never both.
if [ -n "$SSH_CONNECTION" ]; then
  if [ -n "$SSH_TINT_HEX" ]; then
    _SSH_TINT_HEX=$SSH_TINT_HEX
  else
    # shasum hostname → 6 hex chars → halve each channel so it stays dark
    # enough behind light-on-dark text. `${HOST%%.*}` = short hostname.
    _hex=$(printf '%s' "${HOST%%.*}" | shasum | cut -c1-6)
    _r=$(( 16#${_hex:0:2} / 2 ))
    _g=$(( 16#${_hex:2:2} / 2 ))
    _b=$(( 16#${_hex:4:2} / 2 ))
    _SSH_TINT_HEX=$(printf '%02x%02x%02x' "$_r" "$_g" "$_b")
    unset _hex _r _g _b
  fi
  typeset -g _SSH_TINT_HEX

  _ssh_apply_tint() { printf '\033]11;#%s\033\\' "$_SSH_TINT_HEX" }
  _ssh_apply_tint  # initial paint

  # Re-emit on every prompt so nested ssh subshells that clobber OSC 11
  # only steal the background for the duration of their inner session.
  add-zsh-hook precmd _ssh_apply_tint

  # Reset to terminal default when this shell exits — outer shell (or the
  # terminal itself) can re-establish its own preferred background.
  _ssh_reset_tint() { printf '\033]111\033\\' }
  zshexit_functions+=(_ssh_reset_tint)
fi

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

###########################################
# Recover terminal after a suspended TUI (Ctrl-Z)
###########################################
# Claude Code (and other fullscreen TUIs) turn on SGR mouse tracking. Ctrl-Z
# suspends them WITHOUT restoring it, so the shell inherits mouse mode and
# trackpad scroll arrives as arrow keys -> zsh history nav instead of scrollback.
# Disable the mouse-tracking modes before each prompt: idempotent (a no-op when
# nothing leaked), and the TUI re-enables them for itself when you `fg` back in.
_reset_mouse_modes() { print -n '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'; }
add-zsh-hook precmd _reset_mouse_modes
