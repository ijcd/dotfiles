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

# diff variants
alias ddiff="/usr/bin/diff"
alias udiff="/usr/bin/diff -urN"
alias gdiff="git diff --no-index --color-words"

# Lock the screen (when going AFK)
alias afk='osascript -e "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"'

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

###############################
# Debian
###############################
alias acs="apt-cache search"
alias acsh="apt-cache show"
alias acp="apt-cache policy"
alias agi="apt-get install"
