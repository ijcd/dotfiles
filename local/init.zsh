# the basics
: ${HOME=~}
: ${LOGNAME=$(id -un)}
: ${UNAME=$(uname)}

# complete hostnames from this file
: ${HOSTFILE=~/.ssh/known_hosts}

# readline config
: ${INPUTRC=~/.inputrc}

# disable core dumps
ulimit -S -c 0

# default umask
umask 0022

# put ~/bin on PATH if you have it
test -d "$HOME/bin" &&
PATH="$HOME/bin:$PATH"

# ----------------------------------------------------------------------
# ENVIRONMENT CONFIGURATION
# ----------------------------------------------------------------------

# detect interactive shell
if [[ -o interactive ]]; then
    INTERACTIVE=yes
else
	unset INTERACTIVE
fi

# detect login shell
if [[ -o login ]]; then
    LOGIN=yes
else
	unset LOGIN
fi

# enable en_US locale w/ utf-8 encodings if not already configured
: ${LANG:="en_US.UTF-8"}
: ${LANGUAGE:="en"}
: ${LC_CTYPE:="en_US.UTF-8"}
: ${LC_ALL:="en_US.UTF-8"}
export LANG LANGUAGE LC_CTYPE LC_ALL

# always use PASSIVE mode ftp
: ${FTP_PASSIVE:=1}
export FTP_PASSIVE

# ignore backups, CVS directories, python bytecode, vim swap files
FIGNORE="~:CVS:#:.pyc:.swp:.swa:apache-solr-*"

# history stuff
HISTCONTROL=ignoreboth
HISTFILESIZE=10000
HISTSIZE=10000

# ----------------------------------------------------------------------
# PAGER / EDITOR
# ----------------------------------------------------------------------

# See what we have to work with ...
HAVE_VIM=$(command -v vim)
HAVE_GVIM=$(command -v gvim)

# EDITOR
test -n "$HAVE_VIM" &&
EDITOR=vim ||
EDITOR=vi
export EDITOR

# PAGER
if test -n "$(command -v less)" ; then
    PAGER="less -FirSwX"
    MANPAGER="less -FiRswX"
else
    PAGER=more
    MANPAGER="$PAGER"
fi
export PAGER MANPAGER

# Ack
ACK_PAGER="$PAGER"
ACK_PAGER_COLOR="$PAGER"

# ----------------------------------------------------------------------
# MACOS X / DARWIN SPECIFIC
# ----------------------------------------------------------------------

#if [ "$UNAME" = Darwin ]; then
#    # setup java environment. puke.
#    export JAVA_HOME="/System/Library/Frameworks/JavaVM.framework/Home"
#
#    # hold jruby's hand
#    test -d /opt/jruby &&
#    export JRUBY_HOME="/opt/jruby"
#fi

# ----------------------------------------------------------------------
# ALIASES / FUNCTIONS
# ----------------------------------------------------------------------

# Identity
export EMAIL="ian@ianduggan.net"
export FULLNAME="Ian Duggan"

# Prevent ZSH from stating all of Maildir
export MAILCHECK=0

# Debian
export DEBEMAIL=$EMAIL
export DEBFULLNAME=$FULLNAME

# Git
export GIT_AUTHOR_NAME=$FULLNAME
export GIT_COMMITTER_NAME=$FULLNAME
export GIT_AUTHOR_EMAIL=$EMAIL
export GIT_COMMITTER_EMAIL=$EMAIL

# Irc
export IRCNICK=ijcd
export IRCNAME=${FULLNAME}
export IRCSERVER=irc.freenode.net
export IRC_SERVERS_FILE="$HOME/.irc-serv"

# Rsync stuff
export RSYNC_RSH=ssh

# CVS Stuff
export CVS_RSH=ssh
export CVSEDITOR=$EDITOR
export CVSREAD=yes

export CCACHE_DIR=$HOME/.ccache
export CTAGS="--c++-kinds=+p --fields=+iaS --extra=+q"

# Amazon
export EC2_HOME=~/lib/ec2/ec2-api-tools
export EC2_AMITOOL_HOME=~/lib/ec2/ec2-ami-tools
export EC2_PRIVATE_KEY=~/.ssh/ec2/ijcd/pk-C2NZMJYCC4RZ32VD6PT4LMFTNUUTSEJZ.pem
export EC2_CERT=~/.ssh/ec2/ijcd/cert-C2NZMJYCC4RZ32VD6PT4LMFTNUUTSEJZ.pem

export ANT_OPTS="-DXms=1024M -DXmx=1024M -XX:+UseParallelGC"
export MAVEN_OPTS="-Xmx1024m"
export CATALINA_OPTS="-Xms512M -Xmx1024M -XX:PermSize=256M -XX:MaxPermSize=1024M"

# Workflow Stuff
export INBOX=~/Desktop/Inbox
export OUTBOX=~/Desktop/Outbox
export PENDING=~/Desktop/Pending
export I=$INBOX
export O=$OUTBOX
export P=$PENDING

export GNUTERM=x11

# ruby
export RUBYGEMS_GEMDEPS=1

# rails
alias ss=spring

# disk usage with human sizes and minimal depth
alias du1='du -h --max-depth=1'
alias fn='find . -name'
alias h='history | tail -20'
alias hi='history 1'

alias jsonpp='python -mjson.tool'

alias -g mergebase='$(git merge-base master HEAD)'
alias -g thisbranch='$(git rev-parse --abbrev-ref HEAD)'
alias -g thisbranch:thisbranch='$(git rev-parse --abbrev-ref HEAD)':'$(git rev-parse --abbrev-ref HEAD)'

alias rbx="nocorrect rbx"

# commandlinefu
alias head='head -n $(($LINES-2))'

# Mine
alias e='emacs -nw'
alias lpr='lpr -h'
alias space="du -mc | egrep -v '.*/.*/.*' | sort -n"
#alias cd='echo "pushd" ; pushd . > /dev/null ; echo "cd" ; cd $* ; done'
#alias cd=cd-ijcd
alias ud=upd
alias pd=popd-ijcd
alias more=less
alias cvscheck='cvs -n update 2>/dev/null'


alias hh=heroku
alias vv=vagrant

alias gg='cd $(git rev-parse --show-toplevel)'

# RUBY
alias rgems='ruby -rubygems'
alias k='bundle exec knife'
alias be='bundle exec'
alias z=zeus
alias gman='gem man'

alias xmlcurl="curl -H Accept:text/xml $*"

# Mercurial mq
alias mq='hg -R $(hg root)/.hg/patches'

# git
alias g="git"
alias gs="git status"
alias gb="git branch"
alias gd="git diff"
alias gds="git diff --staged"
alias gdh="git diff HEAD"
alias grh="git reset HEAD"
alias gpr="git pull --rebase"

# Lock the screen (when going AFK)
alias afk="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"

# Ring the terminal bell, and put a badge on Terminal.app’s Dock icon
# (useful when executing time-consuming commands)
alias badge="tput bel"
alias ding="tput bel"
alias beep='tput bel'

# dates
yyyymmdd () { date +%Y%m%d ; }
yyyymmdd-hhmmss () { date +%Y%m%d-%H%M%S ; }
alias ymd=yyyymmdd
alias ymd-hms=yyyymmdd-hhmmss

# PATH
for dir in \
    $HOME/bin \
    $HOME/go/bin \
    $HOME/.cargo/bin \
    $HOME/.cabal/bin \
    $HOME/Library/Haskell/bin \
    $(command -v yarn && yarn global bin) \
    $HOME/miniconda3/bin \
    /opt/local/bin \
    /opt/local/sbin \
; do
	if [[ -d $dir ]]; then
	    punshift $dir PATH
	fi
done

# MANPATH
for dir in \
    /usr/share/man \
    /usr/local/share/man \
    /usr/X11/share/man \
    /usr/local/man \
; do
	if [[ -d $dir ]]; then
		punshift $dir MANPATH
	fi
done

# -------------------------------------------------------------------
# USER SHELL ENVIRONMENT
# -------------------------------------------------------------------

# source ~/.shenv now if it exists
test -r ~/.shenv &&
. ~/.shenv

# condense PATH entries
PATH=$(puniq $PATH)
MANPATH=$(puniq $MANPATH)

# -------------------------------------------------------------------
# Maps and Agents
# -------------------------------------------------------------------

# Make Things All Right
#[ -x /bin/stty ] && /bin/stty erase ^? 2>/dev/null
#[ -x /usr/X11R6/bin/xrdb ] && /usr/X11R6/bin/xrdb -load ~/.Xresources 2>/dev/null
#[ -x /usr/X11R6/bin/xmodmap ] && [ -r ~/.xmodmap-`uname -n` ] && /usr/X11R6/bin/xmodmap ~/.xmodmap-`uname -n`

# run keychain and source ssh-agent vars
if [ -z "$SSH_CLIENT" ] ; then
  ssh-reagent || eval `/usr/bin/env keychain --eval id_rsa`
fi
