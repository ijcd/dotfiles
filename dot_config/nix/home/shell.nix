_: {
  # Zsh dotfiles managed by chezmoi (ZDOTDIR=~/.config/zsh)
  # HM generates its zshrc to a separate location, which we source for integrations
  # ~/.zshenv is a symlink managed by chezmoi, so HM doesn't touch it
  programs.zsh = {
    enable = true;
    dotDir = ".local/share/hm-zsh";
    enableCompletion = false;  # Zim handles completion
  };

  # Prevent HM from creating ~/.zshenv (chezmoi manages it as a symlink)
  home.file.".zshenv".enable = false;

  # Starship prompt (config managed by chezmoi, init via HM's zshrc)
  programs.starship.enable = true;
}
