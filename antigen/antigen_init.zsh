# zshenv -> [login? zprofile] -> [interactive? zshrc] -> [login? zlogin] -> [exiting? zlogout]
# After the zlogin scripts are read, if the shell is  interactive, commands are read from /etc/zshrc and then $ZDOTDIR/.zshrc
# An interactive shell reads commands from user input on a tty (a non-script). A shell run as a script is a non-interactive shell
$DOTFILES_NOISY_STARTUP && echo "== Running $HOME/.zshrc"

source $ZPREZTODIR/runcoms/zshrc

# bootstrap dots
. $DOTDIR/modules/dots/dots.zsh
. $DOTDIR/modules/zsh/functions/autoload-fpath
autoload-fpath $DOTDIR/modules/zsh/functions

ZDOTCACHE=~/.zdotcache
# rm -f ~/.zdotcache

# fire up antigen 
source $DOTDIR/antigen/antigen.zsh clone/antigen.zsh

if [ -f $ZDOTCACHE ] ; then
    source $ZDOTCACHE
else
    dots-start-capture $ZDOTCACHE

    # fire up prezto
    # For some reason, "antigen use prezto" is setting ZDOTDIR which prevents .zlogin from running
    antigen bundle sorin-ionescu/prezto

    # import prezto modules
    #       git \
    dots-import-modules prezto \
        with_alias \
            environment \
            terminal \
            editor \
            history \
            directory \
            spectrum \
            utility \
            completion \
            prompt \
            archive \
            command-not-found \
            emacs \
            fasd \
            haskell \
            history-substring-search \
            homebrew \
            node \
            osx \
            screen \
            ssh \
            syntax-highlighting \
            utility \
            fasd \
            tmux

    # import ohmyzsh modules
    #       bundler \  # creates stuff like bundled_ruby (getting in the way right now)
    dots-import-modules ohmyzsh \
        with_alias \
            colored-man \
            debian \
            extract \
            git-extras \
            gem \
            heroku \
            vagrant
    
    # import random modules directly
    antigen bundle zsh-users/zaw
    antigen bundle ijcd/autoenv

    # apply antigen changes
    antigen apply
    
    dots-check-modules
    
    dots-stop-capture
fi

# load local modules
dots-import-modules local $DOTDIR/modules/*

# unexport functions to avoid polluting later shell
dots-unexport-file ~/.zshrc
