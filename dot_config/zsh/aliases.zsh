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

# skip the function/git diff
alias ddiff="/usr/bin/diff"
alias udiff="/usr/bin/diff -urN"

# Lock the screen (when going AFK)
alias afk='osascript -e "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"'

# Change directory to the selected directory using fd and fzf
alias ff='cd $(fd --type d | fzf)'

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

alias nixhome-switch="sudo darwin-rebuild switch --flake ~/.config/nix"
alias nixhome-activate="sudo darwin-rebuild activate --flake ~/.config/nix"

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
