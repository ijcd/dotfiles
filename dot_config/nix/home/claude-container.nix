{ pkgs, lib, ... }:

let
  version = "1.6.1";

  claude-container = pkgs.stdenvNoCC.mkDerivation {
    pname = "claude-container";
    inherit version;
    src = pkgs.fetchFromGitHub {
      owner = "nezhar";
      repo = "claude-container";
      rev = version;
      hash = "sha256-vXgxmuJgTYoyEHGYAGdDB18DaqcioxokesRNq7uuBN4=";
    };
    installPhase = ''
      mkdir -p $out/bin
      cp bin/claude-container $out/bin/
      chmod +x $out/bin/claude-container

      mkdir -p $out/share/bash-completion/completions
      cp completions/claude-container $out/share/bash-completion/completions/
    '';
  };
in
{
  home.packages = [ claude-container ];

  # check for newer releases on switch
  home.activation.checkClaudeContainer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    latest=$(${pkgs.curl}/bin/curl -sf \
      "https://api.github.com/repos/nezhar/claude-container/releases/latest" \
      | ${pkgs.jq}/bin/jq -r '.tag_name // empty' 2>/dev/null) || true
    if [ -n "$latest" ] && [ "$latest" != "${version}" ]; then
      echo "⚠ claude-container ${version} installed, $latest available"
      echo "  Update version in home/claude-container.nix and rebuild"
    fi
  '';
}
