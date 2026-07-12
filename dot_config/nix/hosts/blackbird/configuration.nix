{
  primaryUser,
  lib,
  ...
}:
{
  networking.hostName = "blackbird";

  # lunar-dev profile: machine-wide PostgreSQL 18 for Lunar dev (blackbird only).
  # See lunar-dev.nix. bearcat is unaffected (it keeps its own PG17 module).
  # remote-access: sshd + Screen Sharing so the nixos-antares VM can jump in.
  imports = [
    ./lunar-dev.nix
    ./remote-access.nix
    ./firewall.nix
  ];

  # Corner-case fix: this machine has a hand-installed Homebrew (modern
  # "prefix-is-the-repository" layout) that the pinned nix-homebrew can't adopt
  # (see flake.nix #136 note). Disable nix-homebrew here and let the nix-darwin
  # `homebrew` module drive `brew bundle` against the existing /opt/homebrew.
  # Revisit once nix-homebrew handles the new layout, or nuke+reinstall brew
  # from a session not running off /opt/homebrew.
  nix-homebrew.enable = lib.mkForce false;

  # host-specific home-manager configuration
  home-manager.users.${primaryUser} = {
    # Lunar pgAdmin connection (declarative servers.json + importer).
    imports = [ ./pgadmin-lunar.nix ];

    programs.zsh.initContent = ''
      source ${./shell-functions.sh}
    '';
  };
}
