# check if there's no init script
if ! zgen saved; then

    ztrace () {
        echo "====================================================================="
        echo zgen "$@"

        declare -A binds
        declare -A new_binds

        # collect initial binds into associative array
        for map in $(bindkey -l) ; do
            binds[$map]=$(bindkey -M $map)
        done
        
        zgen "$@"

        # collect finished binds into associative array
        for map in $(bindkey -l) ; do
            new_binds[$map]=$(bindkey -M $map)
        done

        for map in $(bindkey -l) ; do
            if ! diff -q <(echo $binds[$map]) <(echo $new_binds[$map]) >/dev/null
            then
                echo "---------------------------------------"
                echo KEYMAP=$map
                the_diff=$(diff -ud <(echo $binds) <(echo $new_binds))
                echo $the_diff | grep -E '^(\+|-|\!)"'
            fi
        done
    }

    what_binds () {
        for map in $(bindkey -l) ; do
            if [ -n $1 ]
            then
                echo KEYMAP $map $1
            fi
            bindkey -M $map
        done
    }

    echo "Creating a zgen save"
    source "${DOTDIR}/local/boot/save_aliases.zsh"

    ztrace load "${DOTDIR}/local/boot/override_zsh_location.zsh"

    ztrace oh-my-zsh
    ztrace prezto

    # does better if loaded first (k alias gets in the way)
    ztrace load rimraf/k

    # Plugins (oh-my-zsh): https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins
    ztrace oh-my-zsh plugins/ansible
    ztrace oh-my-zsh plugins/asdf
    # ztrace oh-my-zsh plugins/autojump
    ztrace oh-my-zsh plugins/aws
    ztrace oh-my-zsh plugins/battery
    ztrace oh-my-zsh plugins/cabal
    # ztrace oh-my-zsh plugins/cargo #deprecated, moved to rust
    ztrace oh-my-zsh plugins/colored-man-pages
    ztrace oh-my-zsh plugins/debian
    ztrace oh-my-zsh plugins/direnv
    ztrace oh-my-zsh plugins/docker-compose
    ztrace oh-my-zsh plugins/docker-machine
    ztrace oh-my-zsh plugins/docker
    ztrace oh-my-zsh plugins/extract
    # ztrace oh-my-zsh plugins/fzf
    ztrace oh-my-zsh plugins/gatsby
    ztrace oh-my-zsh plugins/gem
    # ztrace oh-my-zsh plugins/git-prompt
    ztrace oh-my-zsh plugins/git-extras
    ztrace oh-my-zsh plugins/golang
    ztrace oh-my-zsh plugins/gpg-agent
    ztrace oh-my-zsh plugins/helm
    # ztrace oh-my-zsh plugins/heroku
    ztrace oh-my-zsh plugins/httpie
    ztrace oh-my-zsh plugins/iterm2
    ztrace oh-my-zsh plugins/kops
    ztrace oh-my-zsh plugins/kubectl
    ztrace oh-my-zsh plugins/magic-enter
    ztrace oh-my-zsh plugins/minikube
    ztrace oh-my-zsh plugins/mix
    ztrace oh-my-zsh plugins/nmap
    ztrace oh-my-zsh plugins/node
    ztrace oh-my-zsh plugins/npm
    # ztrace oh-my-zsh plugins/osx # deprecated for "macos"?
    ztrace oh-my-zsh plugins/macos
    ztrace oh-my-zsh plugins/pip
    ztrace oh-my-zsh plugins/pipenv
    ztrace oh-my-zsh plugins/react-native
    ztrace oh-my-zsh plugins/rust
    # ztrace oh-my-zsh plugins/rustup # deprecated, moved to rust
    ztrace oh-my-zsh plugins/sublime
    ztrace oh-my-zsh plugins/sudo
    ztrace oh-my-zsh plugins/systemd
    ztrace oh-my-zsh plugins/terraform
    ztrace oh-my-zsh plugins/tig
    ztrace oh-my-zsh plugins/ubuntu
    ztrace oh-my-zsh plugins/ufw
    # ztrace oh-my-zsh plugins/vagrant
    ztrace oh-my-zsh plugins/vscode
    ztrace oh-my-zsh plugins/vundle
    ztrace oh-my-zsh plugins/xcode
    ztrace oh-my-zsh plugins/yarn
    # ztrace oh-my-zsh plugins/zsh-interactive-cd

    # Plugins (prezto): https://github.com/sorin-ionescu/prezto/tree/master/modules
    ztrace prezto archive
    ztrace prezto autosuggestions
    ztrace prezto command-not-found
    ztrace prezto completion
    ztrace prezto directory
    # ztrace prezto dnf             # yum package manager
    ztrace prezto docker
    ztrace prezto dpkg
    ztrace prezto editor
    ztrace prezto emacs
    ztrace prezto environment
    ztrace prezto fasd
    ztrace prezto git
    ztrace prezto gnu-utility
    ztrace prezto gpg
    ztrace prezto haskell
    ztrace prezto helper
    ztrace prezto history
    ztrace prezto history-substring-search
    ztrace prezto homebrew
    # ztrace prezto macports
    ztrace prezto node
    ztrace prezto ocaml
    ztrace prezto osx

    # ztrace prezto pacman
    ztrace prezto perl
    ztrace prezto prompt
    ztrace prezto python
    ztrace prezto rails
    ztrace prezto rsync
    ztrace prezto ruby
    ztrace prezto screen
    ztrace prezto spectrum
    ztrace prezto ssh
    ztrace prezto syntax-highlighting
    ztrace prezto terminal
    ztrace prezto tmux
    ztrace prezto utility
    ztrace prezto wakeonlan
    # ztrace prezto yum
    
    # Plugins (other): # https://github.com/unixorn/awesome-zsh-plugins
    ztrace load zsh-users/zaw # zaw (ctrl-x ;) 
    ztrace load zsh-users/zsh-completions src
    ztrace load tarrasch/zsh-bd
    ztrace load caarlos0/zsh-pg
    ztrace load unixorn/git-extra-commands
    ztrace load MenkeTechnologies/zsh-more-completions
    ztrace load zdharma/zsh-diff-so-fancy

    ztrace load marzocchi/zsh-notify
    ztrace load MichaelAquilina/zsh-auto-notify
    ztrace load t413/zsh-background-notify

    # interactive completions
    ztrace oh-my-zsh plugins/fzf
    ztrace oh-my-zsh plugins/zsh-interactive-cd
    ztrace load wookayin/fzf-fasd

    # https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
    # zgen oh-my-zsh themes/arrow

    # save all to init script
    zgen save
    source "${DOTDIR}/local/boot/restore_aliases.zsh"
fi

# look for ohmyzsh modules that could be prezto modules instead
dotfiles-zgen-check-ohmyzsh-vs-prezto

# load local modules
for modname ($DOTDIR/modules/*)
do
    dotfiles-import-local-module $modname
done

# load local misc/overrides
dotfiles-import-local-module $DOTDIR/local

# unexport functions to avoid polluting later shell
dotfiles-unexport-file ~/.zshrc

# set the prompt
autoload -Uz promptinit
promptinit
prompt ijcd
