{ ... }:
{
  # Git config is managed by chezmoi (~/.config/git/config)
  # We just ensure git and related tools are installed via packages.nix
  #
  # Don't use programs.git here - it would generate a config that
  # conflicts with the chezmoi-managed one.

  programs.git.enable = false;
}
