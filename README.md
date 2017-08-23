Dotfiles
========

These are my dotfiles. There are many like them but these ones are mine. I've built these up over a few decades of unix use. Things I use:

* [zsh](https://github.com/zsh-users/zsh)
* [zgen](https://github.com/tarjoilija/zgen)
* [brew](https://github.com/homebrew/homebrew) (OSX)
* [prezto](https://github.com/sorin-ionescu/prezto) (some modules)
* [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh) (some modules)

I use a single git clone and symlink to files within that. I find it works better for me than approaches like vcsh or trying to exclude my entire home directory with .gitignore (an approach I used for years).

Requirements
------------

Set zsh as your login shell:

    chsh -s $(which zsh)

Installing
----------

Dotfiles only

    cd ~
    git clone https://github.com/ijcd/dotfiles.git ~/.dotfiles
    cd ~/.dotfiles
    ./dotfiles install

Stuff from brew (a few things are used by the dotfiles

    brew brewdle

Optional: LOLCAT and Pygments. Adjust the startup if you don't want them.

    sudo gem install lolcat
    sudo easy_install Pygments

Organization
------------

I use modules to organize my dotfiles. Using zgen, I'm able to pull in modules from oh-my-zsh and prezto. Both of these are installed and managed by zgen.

Loading happens in a few steps, starting from modules/zsh/zshrc.symlink which is symlinked by the system as ~/.zshrc

In addition to the oh-my-zsh and prezto modules, I have all of my local customization organized by major topic area with a local module loading function (dotfiles-import-local-module) and installation script that do the following for each module:

* symlink all files/directories named *.symlink to the correspondinging dotfile in ~
* add $modpath/bin to the path
* add $modpath/functions to the fpath (for autoloading functions)
* source all $modpath/*.zsh files

Most modules are located in modules/$moddir. All files in modules/* are sourced at startup by zshrc.symlink. There is a top-level module called "local" with more recent, less organized things that is also sourced.

Customizing
-----------

Start by looking at these files and go from there:

* dotfiles
* modules/zsh/zshrc.symlink
* local/*

Resync things by running:

    ./dotfiles install

Fun Things
----------

* **zaw**: ctrl-x ctrl-;
* **command search**: ctrl-r
* **plugins**: https://github.com/unixorn/awesome-zsh-plugins
* **ponies**: https://github.com/mika/zsh-pony
* **tricks**: http://reasoniamhere.com/2014/01/11/outrageously-useful-tips-to-master-your-z-shell/
* **pick**: https://github.com/thoughtbot/pick

Inspiration
-----------

* [yadr](https://github.com/skwp/dotfiles)
* [rtomayko](https://github.com/rtomayko/dotfiles)
* [matiasbynens](https://github.com/mathiasbynens/dotfiles)
* [sorin-ionescu](https://github.com/sorin-ionescu/dotfiles)

History
-------

I've been using zsh since 1995 or so. I used antigen for a year (patched to create a dotfile cache like zgen does, never released that -- see dots.zsh ...). I switched to zgen lately and cleaned everything up. Here you go.
