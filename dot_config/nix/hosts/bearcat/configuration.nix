{
  primaryUser,
  ...
}:
let
  groups = import ../../darwin/cask-groups.nix;
in
{
  networking.hostName = "bearcat";

  # bearcat is the home machine: add personal/creative groups + heavy SDKs on
  # top of the shared base from darwin/homebrew.nix. (Lists concatenate.)
  homebrew.casks = with groups;
    creative
    ++ media
    ++ personalComms
    ++ personalInfra
    ++ personalMisc
    ++ homeDevExtra
    ++ heavySdks;

  # host-specific home-manager configuration
  home-manager.users.${primaryUser} = {
    programs.zsh.initContent = ''
      source ${./shell-functions.sh}
    '';
  };
}
