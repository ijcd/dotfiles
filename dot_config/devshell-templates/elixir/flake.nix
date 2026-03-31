{
  description = "Elixir dev shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-darwin" "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
    in {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              elixir
              erlang
              hex
              rebar3
              postgresql
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              inotify-tools
            ];

            shellHook = ''
              export LANG=en_US.UTF-8
              export ERL_AFLAGS="-kernel shell_history enabled"
              export MIX_HOME="$PWD/.mix"
              export HEX_HOME="$PWD/.hex"
              mkdir -p "$MIX_HOME" "$HEX_HOME"
            '';
          };
        });
    };
}
