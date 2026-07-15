{ pkgs, config, lib, ... }:
let
  homeDir = config.home.homeDirectory;
  logDir = "${homeDir}/.local/state/local-ai";

  # Wrapper: source the (optional, 0600, user-created) key file, then exec the
  # proxy. Keeps ANTHROPIC_API_KEY out of the nix store and out of git. Absent
  # key file → local aliases still work; only `smart`/`auto`-fallback need it.
  litellmLauncher = pkgs.writeShellScript "litellm-launch" ''
    set -a
    [ -f "${homeDir}/.config/litellm/env" ] && . "${homeDir}/.config/litellm/env"
    set +a
    exec ${pkgs.litellm}/bin/litellm \
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
