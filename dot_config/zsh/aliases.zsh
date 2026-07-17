###########
# Safety - prevent accidental overwrites
###########
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'

###########
# MISC
###########

# zmv - powerful rename/copy/link with patterns
# Usage: zmv '(*).txt' '$1.md'  -- rename all .txt to .md
autoload -U zmv
alias zmv="noglob zmv -W"
alias zcp="noglob zmv -C"
alias zln="noglob zmv -L"

alias la="ls -la";
alias ..="cd ..";

# print PATH/FPATH as lines (zsh $path array)
alias path='print -l $path'
alias fpath='print -l $fpath'

# all history
alias hh='history 1'

# no banner for lpr
alias lpr='lpr -h'

# quick disk usage
alias show-space="du -mc | egrep -v '.*/.*/.*' | sort -n"

# simple find (fn '*.zsh')
alias fn='find . -name'

# ripgrep (ignore)
alias rgi="rg --no-ignore"

# Tailscale
alias ts='tailscale'
alias tsstatus='tailscale status'
alias tsnetcheck='tailscale netcheck'
alias tspong='tailscale ping'      # verify direct P2P (not DERP-relayed)

# diff variants
alias ddiff="/usr/bin/diff"
alias udiff="/usr/bin/diff -urN"
alias gdiff="git diff --no-index --color-words"

# Lock the screen (when going AFK)
alias afk='osascript -e "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"'

# sleepnow: kill any lingering caffeinate holders (Claude Code, etc.) and force
# immediate sleep. Use before putting the laptop in a bag so it doesn't stew.
sleepnow() {
  killall -q caffeinate 2>/dev/null
  sudo pmset sleepnow
}

# Change directory to the selected directory using fd and fzf
alias ff='cd $(fd --type d | fzf)'

# zoxide (muscle memory from fasd/autojump days)
# j is a function (not alias) so completions work - see tools.zsh

# todos
alias todos-show="rg -n '(TODO|FIXME|XXX|HACK)'"
alias todos-pick="rg -n '(TODO|FIXME|XXX|HACK)' | \
  fzf --ansi --delimiter : \
      --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
      --bind 'enter:execute-silent(zed {1}:{2})+reload:rg -n \"(TODO|FIXME|XXX|HACK)\"'"

############
# home-dir management
############
alias cm=chezmoi

alias nixhome-switch='sudo -H nix run nix-darwin -- switch --flake /Users/$USER/.config/nix'
alias nixhome-activate='sudo nix run nix-darwin -- activate --flake ~/.config/nix'

alias whatchanged-cm="~/.config/nix/scripts/chezmoi-report.sh";
alias whatchanged-nixhome="~/.config/nix/scripts/nixhome-report.sh";

############
# git
############

alias g="git"
alias gs="git status"
alias gb="git branch"
alias gd="git diff"
alias gds="git diff --staged"
alias gdh="git diff HEAD"
alias grh="git reset HEAD"
alias gpr="git pull --rebase"

alias gg='cd $(git rev-parse --show-toplevel)'     # git cd to root

# TODO: Move to functions?
# git merge shortcuts
alias -g mergebase='$(git merge-base master HEAD)'
alias -g thisbranch='$(git rev-parse --abbrev-ref HEAD)'
alias -g thisbranch:thisbranch='$(git rev-parse --abbrev-ref HEAD)':'$(git rev-parse --abbrev-ref HEAD)'


# TODO:
# 🗑 Toss (or keep only until you migrate off fasd)
#
# These either add noise, overlap with better tools, or are tied to fasd, which you’re
# very likely to replace with zoxide + fzf + fd.
#
# given you’re already on `fd` + `fzf` and flirting with Nix,
# I’d move to zoxide or just keep:
#   ff='cd $(fd --type d | fzf)'
# and kill the fasd set entirely.
#
# alias a='fasd -a'        # any
# alias s='fasd -si'       # show / search / select
# alias d='fasd -d'        # directory
# alias f='fasd -f'        # file
# alias sd='fasd -sid'     # interactive directory selection
# alias sf='fasd -sif'     # interactive file selection
# alias z='fasd_cd -d'     # cd, same functionality as j in autojump
# alias zz='fasd_cd -d -i' # cd with interactive selection
# alias j='fasd_cd -d'     # muscle memory
# alias jj='fasd_cd -d -i' # cd with interactive selection

############
# media (yt script in ~/.local/bin)
############
alias ytv='mpv'                                        # video (foreground)

############
# emacs
############
alias emacs-start='emacs --daemon'
alias emacs-stop='emacsclient -e "(kill-emacs)"'

# Open file(s) in running Emacs (current frame, return to shell immediately).
# - No args: bring Emacs to foreground.
# - With args: open files, print resolved paths as clickable links (OSC 8).
# Alternative location: ~/.config/zsh/functions/e (autoloaded). Currently inline.
e() {
  if [[ $# -eq 0 ]]; then
    open -a Emacs 2>/dev/null \
      || emacsclient -n -e '(x-focus-frame nil)' >/dev/null
    return
  fi
  emacsclient -n "$@" || return
  emacsclient -n -e '(x-focus-frame nil)' >/dev/null 2>&1
  local n=$#
  printf 'opened %d file%s in Emacs:\n' $n $([[ $n -eq 1 ]] && echo '' || echo 's')
  for f in "$@"; do
    local abs
    abs="$(realpath "$f" 2>/dev/null || echo "$f")"
    printf '  \033]8;;file://%s\033\\%s\033]8;;\033\\\n' "$abs" "$abs"
  done
}

# Terminal frame variant — blocks until C-x # (good for git commits, ssh)
alias et='emacsclient -t'

# teecap — show output AND copy to macOS clipboard. Strips ANSI escape codes
# from the clipboard copy; terminal still sees colors.
#
# Implementation: command's stdout → temp file (not pipe) → tail -f streams
# to terminal. This avoids the classic "VM-children hold the pipe open after
# the parent exits" deadlock (mix/iex/beam, npm, gradle, etc.). The piped
# form is still pipe-based and inherits that limitation if your source
# command has stragglers.
#
# Usage:
#   teecap -- mix test.all             # -- delimiter (optional, for clarity)
#   teecap eask compile                # command directly
#   { c1 && c2 ; } 2>&1 | teecap       # piped form (for compound pipelines)
teecap() {
  [[ "$1" == "--" ]] && shift
  # Local zsh options: silence job-control noise + force-allow clobber
  # of the mktemp-created file via `>|`.
  setopt local_options no_notify no_monitor 2>/dev/null
  local tmpfile rc=0
  tmpfile=$(mktemp -t teecap.XXXXXX) || return 1
  # Trap clean up on any exit path (Ctrl+C, return, error).
  trap "rm -f '$tmpfile'" EXIT INT TERM HUP
  if (( $# > 0 )); then
    "$@" >| "$tmpfile" 2>&1 &
    local cmdpid=$! tailpid
    # -n +1 forces tail to start at byte 0 (default is EOF), avoiding the
    # race where cmd writes before tail attaches. Compound { } wraps the redirect
    # so bash's redirect-setup error (no controlling tty) is also caught.
    { tail -f -n +1 "$tmpfile" >/dev/tty; } 2>/dev/null &
    tailpid=$!
    wait $cmdpid; rc=$?
    sleep 0.1                        # drain remaining tail output
    kill $tailpid 2>/dev/null
    wait $tailpid 2>/dev/null
  else
    tee /dev/tty >| "$tmpfile"
  fi
  sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' < "$tmpfile" | pbcopy
  rm -f "$tmpfile"
  trap - EXIT INT TERM HUP
  return $rc
}

###############################
# Debian
###############################
alias acs="apt-cache search"
alias acsh="apt-cache show"
alias acp="apt-cache policy"
alias agi="apt-get install"

###############################
# Terminal
###############################
# fixterm: undo the terminal modes a fullscreen TUI (e.g. a Ctrl-Z'd Claude
# Code) leaves behind — alt-screen, mouse tracking, focus reporting — that make
# the wheel and PageUp/Down scroll command history instead of the scrollback.
# \e[<u pops the kitty keyboard protocol (CSI-u) a fullscreen TUI leaves on,
# which otherwise makes Ctrl-A/E/F/B send escape sequences zsh prints as junk.
alias fixterm='printf "\e[?1049l\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1004l\e[<u"'
