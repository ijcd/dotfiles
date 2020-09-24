# # the basics
# : ${HOME=~}
# : ${LOGNAME=$(id -un)}
# : ${UNAME=$(uname)}

# # complete hostnames from this file
# : ${HOSTFILE=~/.ssh/known_hosts}

# # readline config
# : ${INPUTRC=~/.inputrc}

# # enable en_US locale w/ utf-8 encodings if not already configured
# : ${LANG:="en_US.UTF-8"}
# : ${LANGUAGE:="en"}
# : ${LC_CTYPE:="en_US.UTF-8"}
# : ${LC_ALL:="en_US.UTF-8"}
# export LANG LANGUAGE LC_CTYPE LC_ALL

# # always use PASSIVE mode ftp
# : ${FTP_PASSIVE:=1}
# export FTP_PASSIVE

# # ignore backups, CVS directories, python bytecode, vim swap files
# FIGNORE="~:CVS:#:.pyc:.swp:.swa:apache-solr-*"

# # history stuff
# HISTCONTROL=ignoreboth
# HISTFILESIZE=10000
# HISTSIZE=10000

# # ----------------------------------------------------------------------
# # PAGER / EDITOR
# # ----------------------------------------------------------------------

# # See what we have to work with ...
# HAVE_VIM=$(command -v vim)
# HAVE_GVIM=$(command -v gvim)

# # EDITOR
# test -n "$HAVE_VIM" && EDITOR=vim || EDITOR=vi
# export EDITOR

# # PAGER
# if test -n "$(command -v less)" ; then
#     PAGER="less -FirSwX"
#     MANPAGER="less -FiRswX"
# else
#     PAGER=more
#     MANPAGER="$PAGER"
# fi
# export PAGER MANPAGER

# # Ack
# ACK_PAGER="$PAGER"
# ACK_PAGER_COLOR="$PAGER"

# # Identity
# export EMAIL="ian@ianduggan.net"
# export FULLNAME="Ian Duggan"

# # Prevent ZSH from stating all of Maildir
# export MAILCHECK=0

# # Debian
# export DEBEMAIL=$EMAIL
# export DEBFULLNAME=$FULLNAME

# # Git
# export GIT_AUTHOR_NAME=$FULLNAME
# export GIT_COMMITTER_NAME=$FULLNAME
# export GIT_AUTHOR_EMAIL=$EMAIL
# export GIT_COMMITTER_EMAIL=$EMAIL

# # Irc
# export IRCNICK=ijcd
# export IRCNAME=${FULLNAME}
# export IRCSERVER=irc.freenode.net
# export IRC_SERVERS_FILE="$HOME/.irc-serv"

# # Rsync stuff
# export RSYNC_RSH=ssh

# # CVS Stuff
# export CVS_RSH=ssh
# export CVSEDITOR=$EDITOR
# export CVSREAD=yes

# export CCACHE_DIR=$HOME/.ccache
# export CTAGS="--c++-kinds=+p --fields=+iaS --extra=+q"

# # Amazon
# export EC2_HOME=~/lib/ec2/ec2-api-tools
# export EC2_AMITOOL_HOME=~/lib/ec2/ec2-ami-tools
# export EC2_PRIVATE_KEY=~/.ssh/ec2/ijcd/pk-C2NZMJYCC4RZ32VD6PT4LMFTNUUTSEJZ.pem
# export EC2_CERT=~/.ssh/ec2/ijcd/cert-C2NZMJYCC4RZ32VD6PT4LMFTNUUTSEJZ.pem

# export ANT_OPTS="-DXms=1024M -DXmx=1024M -XX:+UseParallelGC"
# export MAVEN_OPTS="-Xmx1024m"
# export CATALINA_OPTS="-Xms512M -Xmx1024M -XX:PermSize=256M -XX:MaxPermSize=1024M"

# # Workflow Stuff
# export INBOX=~/Desktop/Inbox
# export OUTBOX=~/Desktop/Outbox
# export PENDING=~/Desktop/Pending
# export I=$INBOX
# export O=$OUTBOX
# export P=$PENDING

# export GNUTERM=x11
