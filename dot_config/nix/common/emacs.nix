{ pkgs, config, lib, ... }:
{
  programs.emacs = {
    enable = true;
    package = if pkgs.stdenv.isDarwin then pkgs.emacs else pkgs.emacs-pgtk;
    extraPackages = epkgs: with epkgs; [
      vterm
      treesit-grammars.with-all-grammars
    ];
  };

  # Copy Emacs.app to ~/Applications so macOS Spotlight/Alfred can find it.
  # recursive = true forces a real copy instead of a Nix store symlink.
  home.file = lib.mkIf pkgs.stdenv.isDarwin {
    "Applications/Emacs.app" = {
      source = "${config.programs.emacs.finalPackage}/Applications/Emacs.app";
      recursive = true;
    };
  };
}
