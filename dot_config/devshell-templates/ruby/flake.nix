{
  description = "Ruby dev shell";

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
              ruby
              bundler
              solargraph
              libyaml
            ];

            shellHook = ''
              export GEM_HOME="$PWD/.gems"
              export PATH="$GEM_HOME/bin:$PATH"
              mkdir -p "$GEM_HOME"
            '';
          };
        });
    };
}
