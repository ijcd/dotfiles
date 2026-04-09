{ pkgs, ... }:
{
  programs.emacs = {
    enable = true;
    package = if pkgs.stdenv.isDarwin then pkgs.emacs else pkgs.emacs-pgtk;
    extraPackages = epkgs: with epkgs; [
      vterm
      treesit-grammars.with-all-grammars
    ];
  };
}
