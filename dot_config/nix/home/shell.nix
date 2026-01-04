_: {
  # Zsh dotfiles managed by chezmoi (ZDOTDIR=~/.config/zsh)
  # HM generates its config to a separate location, which we source for integrations
  programs.zsh = {
    enable = true;
    dotDir = ".local/share/hm-zsh";

    # Source chezmoi-managed zshenv (backed up to .mine by HM)
    envExtra = ''
      [[ -f "$HOME/.zshenv.mine" ]] && source "$HOME/.zshenv.mine"
    '';
  };

  # Starship prompt (config managed by chezmoi, init via HM's zshrc)
  programs.starship.enable = true;
}
