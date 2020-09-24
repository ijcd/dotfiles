# disk usage with human sizes and minimal depth
alias du1='du -h --max-depth=1'
alias fn='find . -name'
alias h='history | tail -20'
alias hi='history 1'

alias jsonpp='python -mjson.tool'

# https://www.commandlinefu.com/commands/view/5312/alias-head-for-automatic-smart-output
alias head='head -n $((${LINES:-`tput lines 2>/dev/null||echo -n 12`} - 2))'

# Mine
alias lpr='lpr -h'
alias space="du -mc | egrep -v '.*/.*/.*' | sort -n"
alias more=less

# Random
alias xmlcurl="curl -H Accept:text/xml $*"

# git
alias g="git"
alias gs="git status"
alias gb="git branch"
alias gd="git diff"
alias gds="git diff --staged"
alias gdh="git diff HEAD"
alias grh="git reset HEAD"
alias gpr="git pull --rebase"

# git merge shortcuts
alias -g mergebase='$(git merge-base master HEAD)'
alias -g thisbranch='$(git rev-parse --abbrev-ref HEAD)'
alias -g thisbranch:thisbranch='$(git rev-parse --abbrev-ref HEAD)':'$(git rev-parse --abbrev-ref HEAD)'

# git cd to root
alias gg='cd $(git rev-parse --show-toplevel)'

# Lock the screen (when going AFK)
alias afk="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"

