{ pkgs, config, lib, ... }:
let
  homeDir = config.home.homeDirectory;
  logDir = "${homeDir}/.local/state/local-ai";

  # Wrapper: source the (optional, 0600, user-created) key file, then exec the
  # proxy. Keeps ANTHROPIC_API_KEY out of the nix store and out of git. Absent
  # key file → local aliases still work; only `smart`/`auto`-fallback need it.
  #
  # litellm binary comes from a user-managed install, not nix: pyarrow (a
  # litellm dep) propagates arrow-cpp 23.0.0 which nixpkgs marks broken on
  # x86_64-darwin. Install with `uv tool install litellm` or `pipx install
  # litellm` — both land the binary at ~/.local/bin/litellm.
  litellmBin = "${homeDir}/.local/bin/litellm";
  litellmLauncher = pkgs.writeShellScript "litellm-launch" ''
    set -a
    [ -f "${homeDir}/.config/litellm/env" ] && . "${homeDir}/.config/litellm/env"
    set +a
    if [ ! -x "${litellmBin}" ]; then
      echo "litellm not installed at ${litellmBin} — install with: uv tool install litellm" >&2
      exit 78  # EX_CONFIG
    fi
    exec "${litellmBin}" \
      --config "${homeDir}/.config/litellm/config.yaml" \
      --host 127.0.0.1 --port 4000
  '';
in
{
  # First launchd user-agents in this repo. Home Manager writes plists to
  # ~/Library/LaunchAgents and load/unloads them on activation.
  # Model blobs live at ~/.local/share/ollama (via the ~/.ollama symlink in
  # shell.nix); OLLAMA_MODELS is a shell-only var, so set the model path here
  # too — launchd agents do not source the login shell.
  home.activation.ensureLocalAiLogDir =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${logDir}"
    '';

  launchd.agents.ollama = {
    enable = true;
    config = {
      ProgramArguments = [ "${pkgs.ollama}/bin/ollama" "serve" ];
      EnvironmentVariables = {
        OLLAMA_MODELS = "${homeDir}/.local/share/ollama/models";
        OLLAMA_HOST = "127.0.0.1:11434";
        OLLAMA_CONTEXT_LENGTH = "32768"; # tool calls need headroom; docs bury this
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/ollama.out.log";
      StandardErrorPath = "${logDir}/ollama.err.log";
    };
  };

  launchd.agents.litellm = {
    enable = true;
    config = {
      ProgramArguments = [ "${litellmLauncher}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/litellm.out.log";
      StandardErrorPath = "${logDir}/litellm.err.log";
    };
  };
}
