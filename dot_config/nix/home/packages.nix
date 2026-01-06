{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      # dev tools
      curl
      vim
      tmux
      htop
      tree
      ripgrep
      gh
      zoxide
      delta

      # programming languages
      mise # node, deno, bun, rust, python, etc.

      # misc
      nil                # nix LSP
      biome              # JS/TS linter/formatter
      nixfmt-rfc-style   # nix formatter
      yt-dlp             # youtube downloader
      ffmpeg             # video/audio processing
      ollama             # local LLMs
      poppler_utils      # pdfunite, pdftotext, etc.

      # fonts
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
    ];
  };
}
