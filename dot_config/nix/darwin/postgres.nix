{ pkgs, lib, primaryUser, ... }:
let
  dataDir = "/Users/${primaryUser}/.local/share/postgres";
  logDir = "${dataDir}/logs";
in
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    dataDir = dataDir;
    port = 5432;
    enableTCPIP = false;

    # Trust all local connections (single-user dev machine)
    authentication = ''
      local all all              trust
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128      trust
    '';

    settings = {
      # Logging with database name for filtering
      log_destination = "stderr";
      logging_collector = "on";
      log_directory = logDir;
      log_filename = "postgresql-%Y-%m-%d.log";
      log_rotation_age = "1d";
      log_rotation_size = "100MB";
      log_line_prefix = lib.mkForce "%t [%d] [%p] ";

      # What to log
      log_statement = "ddl";
      log_min_duration_statement = 1000;
      log_connections = "on";
      log_disconnections = "on";

      # Unix socket in data dir
      unix_socket_directories = dataDir;
    };

    initdbArgs = [ "--no-locale" "--encoding=UTF8" ];
  };

  # Ensure log directory exists
  system.activationScripts.postgresLogDir.text = ''
    mkdir -p ${logDir}
    chown ${primaryUser} ${logDir}
  '';

  # No CLI package here: the psql/pg_dump CLIENT comes from the base
  # (common/packages.nix, postgresql_18). This module only runs the server
  # service. Two postgresql packages in systemPackages would collide on psql.
}
