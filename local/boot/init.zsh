# check if there's no init script
if ! zgen saved; then
    echo "Creating a zgen save"
    source "${DOTDIR}/local/boot/save_aliases.zsh"

    # Plugins (oh-my-zsh): https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins
    zgen oh-my-zsh
    zgen oh-my-zsh plugins/ansible
    zgen oh-my-zsh plugins/asdf
    # zgen oh-my-zsh plugins/autojump
    zgen oh-my-zsh plugins/aws
    zgen oh-my-zsh plugins/battery
    zgen oh-my-zsh plugins/cabal
    zgen oh-my-zsh plugins/cargo
    zgen oh-my-zsh plugins/colored-man-pages
    zgen oh-my-zsh plugins/debian
    zgen oh-my-zsh plugins/direnv
    zgen oh-my-zsh plugins/docker-compose
    zgen oh-my-zsh plugins/docker-machine
    zgen oh-my-zsh plugins/docker
    zgen oh-my-zsh plugins/extract
    zgen oh-my-zsh plugins/fzf
    zgen oh-my-zsh plugins/gatsby
    zgen oh-my-zsh plugins/gem
    # zgen oh-my-zsh plugins/git-prompt
    zgen oh-my-zsh plugins/git-extras
    zgen oh-my-zsh plugins/golang
    zgen oh-my-zsh plugins/gpg-agent
    zgen oh-my-zsh plugins/helm
    # zgen oh-my-zsh plugins/heroku
    zgen oh-my-zsh plugins/httpie
    zgen oh-my-zsh plugins/iterm2
    zgen oh-my-zsh plugins/kops
    zgen oh-my-zsh plugins/kubectl
    zgen oh-my-zsh plugins/magic-enter
    zgen oh-my-zsh plugins/minikube
    zgen oh-my-zsh plugins/mix
    zgen oh-my-zsh plugins/nmap
    zgen oh-my-zsh plugins/node
    zgen oh-my-zsh plugins/npm
    zgen oh-my-zsh plugins/osx
    zgen oh-my-zsh plugins/pip
    zgen oh-my-zsh plugins/pipenv
    zgen oh-my-zsh plugins/react-native
    zgen oh-my-zsh plugins/rust
    zgen oh-my-zsh plugins/rustup
    zgen oh-my-zsh plugins/sublime
    zgen oh-my-zsh plugins/sudo
    zgen oh-my-zsh plugins/systemd
    zgen oh-my-zsh plugins/terraform
    zgen oh-my-zsh plugins/tig
    zgen oh-my-zsh plugins/ubuntu
    zgen oh-my-zsh plugins/ufw
    # zgen oh-my-zsh plugins/vagrant
    zgen oh-my-zsh plugins/vscode
    zgen oh-my-zsh plugins/vundle
    zgen oh-my-zsh plugins/xcode
    zgen oh-my-zsh plugins/yarn
    zgen oh-my-zsh plugins/zsh-interactive-cd


    # Plugins (prezto): https://github.com/sorin-ionescu/prezto/tree/master/modules
    zgen prezto
    zgen prezto archive
    zgen prezto autosuggestions
    zgen prezto command-not-found
    zgen prezto completion
    zgen prezto directory
    # zgen prezto dnf             # yum package manager
    zgen prezto docker
    zgen prezto dpkg
    zgen prezto editor
    zgen prezto emacs
    zgen prezto environment
    # zgen prezto fasd
    zgen prezto git
    zgen prezto gnu-utility
    zgen prezto gpg
    zgen prezto haskell
    zgen prezto helper
    zgen prezto history
    zgen prezto history-substring-search
    zgen prezto homebrew
    # zgen prezto macports
    zgen prezto node
    zgen prezto ocaml
    zgen prezto osx
    # zgen prezto pacman
    zgen prezto perl
    zgen prezto prompt
    zgen prezto python
    zgen prezto rails
    zgen prezto rsync
    zgen prezto ruby
    zgen prezto screen
    zgen prezto spectrum
    zgen prezto ssh
    zgen prezto syntax-highlighting
    zgen prezto terminal
    zgen prezto tmux
    zgen prezto utility
    zgen prezto wakeonlan
    # zgen prezto yum

    
    # Plugins (other): # https://github.com/unixorn/awesome-zsh-plugins
    zgen load zsh-users/zaw # zaw (ctrl-x ;) 
    zgen load zsh-users/zsh-completions src
    zgen load rimraf/k
    zgen load tarrasch/zsh-bd
    zgen load caarlos0/zsh-pg
    zgen load unixorn/git-extra-commands
    zgen load MenkeTechnologies/zsh-more-completions

    zgen load marzocchi/zsh-notify
    zgen load MichaelAquilina/zsh-auto-notify
    zgen load t413/zsh-background-notify

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
