{
  primaryUser,
  lib,
  ...
}:
{
  networking.hostName = "blackbird";

  # Corner-case fix: this machine has a hand-installed Homebrew (modern
  # "prefix-is-the-repository" layout) that the pinned nix-homebrew can't adopt
  # (see flake.nix #136 note). Disable nix-homebrew here and let the nix-darwin
  # `homebrew` module drive `brew bundle` against the existing /opt/homebrew.
  # Revisit once nix-homebrew handles the new layout, or nuke+reinstall brew
  # from a session not running off /opt/homebrew.
  nix-homebrew.enable = lib.mkForce false;

  # host-specific home-manager configuration
  home-manager.users.${primaryUser} = {
    programs.zsh.initContent = ''
      source ${./shell-functions.sh}
    '';
  };
}
