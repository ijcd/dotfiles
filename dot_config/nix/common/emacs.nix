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

  # copilot.el's language server runs on Node. This is a leaf tool-dep for
  # Emacs, not a project runtime — colocated here with its consumer. Inside a
  # project, mise's node shadows it; outside, Emacs still has one.
  home.packages = [ pkgs.nodejs ];
}
