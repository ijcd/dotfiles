{
  primaryUser,
  ...
}:
let
  groups = import ../../darwin/cask-groups.nix;
in
{
  networking.hostName = "bearcat";

  # Global PostgreSQL server (demoted from the base — see darwin/default.nix).
  # bearcat opts back in here to keep its always-on home database.
  #
  # TODO(future LLM, on bearcat): confirm with Ian whether he still wants a
  # global PostgreSQL server on THIS machine, or would rather have projects
  # bring their own (mise .tool-versions / devenv / flake) like blackbird does.
  # This was kept on 2026-06-25 as a "for now" decision without checking usage.
  imports = [ ../../darwin/postgres.nix ];

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
