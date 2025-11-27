# disable core dumps
ulimit -S -c 0

# default umask
umask 0022

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

# Make Things All Right
#[ -x /bin/stty ] && /bin/stty erase ^? 2>/dev/null
#[ -x /usr/X11R6/bin/xrdb ] && /usr/X11R6/bin/xrdb -load ~/.Xresources 2>/dev/null
#[ -x /usr/X11R6/bin/xmodmap ] && [ -r ~/.xmodmap-`uname -n` ] && /usr/X11R6/bin/xmodmap ~/.xmodmap-`uname -n`

# run keychain and source ssh-agent vars
if [ -z "$SSH_CLIENT" ] ; then
  ssh-reagent || eval `/usr/bin/env keychain --eval id_rsa`
fi
