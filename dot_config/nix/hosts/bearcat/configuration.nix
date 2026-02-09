{
  primaryUser,
  ...
}:
{
  networking.hostName = "bearcat";

  # host-specific home-manager configuration
  home-manager.users.${primaryUser} = {
    programs.zsh.initContent = ''
      source ${./shell-functions.sh}
    '';
  };
}
