{
  description = "Python dev shell";

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
              python3
              python3Packages.pip
              python3Packages.virtualenv
              black
              ruff
              mypy
            ];

            shellHook = ''
              export PIP_PREFIX="$PWD/.pip"
              export PYTHONPATH="$PIP_PREFIX/lib/python3.12/site-packages:$PYTHONPATH"
              export PATH="$PIP_PREFIX/bin:$PATH"
              mkdir -p "$PIP_PREFIX"
            '';
          };
        });
    };
}
