{ pkgs, lib, config, ... }:
{
  # ─────────────────────────────────────────────────────────────────────────────
  # DISABLED: nix-built mise has HTTP bugs on x86_64-darwin (Rust 1.88 issue)
  # See: https://github.com/NixOS/nixpkgs/issues/427748
  # Using homebrew mise instead. Re-enable when nixpkgs fixes the issue.
  # ─────────────────────────────────────────────────────────────────────────────
  # programs.mise = {
  #   enable = true;
  #   enableZshIntegration = true;
  #
  #   settings = {
  #     experimental = true;
  #     verbose = false;
  #     auto_install = true;
  #   };
  # };

  # zsh integration for homebrew mise (replaces programs.mise.enableZshIntegration)
  programs.zsh.initContent = lib.mkAfter ''
    # mise (homebrew) - version manager
    if command -v mise >/dev/null 2>&1; then
      eval "$(mise activate zsh)"
    fi
  '';

  # activation script to set up mise configuration (uses homebrew mise)
  home.activation.setupMise = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v mise >/dev/null 2>&1; then
      # enable corepack (pnpm, yarn, etc.)
      mise set MISE_NODE_COREPACK=true

      # disable warning about */.node-version files
      mise settings add idiomatic_version_file_enable_tools "[]"

      # set global tool versions (auto_install will handle installation)
      # mise use --global node@lts
      # mise use --global bun@latest
      # mise use --global deno@latest
      # mise use --global uv@latest
      # mise use --global rust@stable
    fi
  '';
}
