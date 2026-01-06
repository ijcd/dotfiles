{ primaryUser, ... }:
{
  programs.git = {
    enable = true;
    userName = "YOUR_NAME"; # TODO replace
    userEmail = "YOUR_EMAIL"; # TODO replace

    lfs.enable = true;

    ignores = [ "**/.DS_STORE" ];

    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Dracula";
      };
    };

    extraConfig = {
      github = {
        user = primaryUser;
      };
      init = {
        defaultBranch = "main";
      };
      merge = {
        conflictstyle = "diff3";
      };
      diff = {
        colorMoved = "default";
      };
    };
  };
}
