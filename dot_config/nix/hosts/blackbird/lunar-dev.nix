# lunar-dev profile — blackbird only.
#
# Machine-wide PostgreSQL 18 for Lunar dev, replacing the per-user mise postgres.
# On 2026-07-09 the existing 8.8G PG18 cluster was reused in place (nix skips
# initdb when $dataDir/PG_VERSION exists), so all roles/DBs are preserved.
#
# Datadir is ~/pgsql/<project>-<pgmajor> (here: ~/pgsql/lunar-18). The
# project+version naming lets multiple clusters coexist under ~/pgsql without
# datadir collisions — e.g. a future lunar-19 during a major upgrade, or a
# second project. (They'd still need distinct ports to run concurrently; only
# lunar runs on 5432 today.)
#
# Lunar's dev repos connect over TCP localhost:5432 as user "postgres"
# (see apps' config/dev_runtime_defaults.exs), so TCP is enabled, bound to
# loopback only, and local connections are trusted (single-user dev machine —
# the "postgres"/"postgres" password in lunar's config is moot under trust).
#
# postgresql_18 is REQUIRED: a PG18 datadir cannot be opened by _17
# (bearcat's darwin/postgres.nix). This is kept as a SEPARATE blackbird-only
# module rather than parameterizing darwin/postgres.nix, so bearcat (PG17,
# socket-only, its own datadir) is untouched.
{ pkgs, lib, primaryUser, ... }:
let
  dataDir = "/Users/${primaryUser}/pgsql/lunar-18";
  logDir = "${dataDir}/logs";
in
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18; # must match the on-disk PG18 cluster
    dataDir = dataDir;
    port = 5432;
    enableTCPIP = true; # lunar connects hostname: "localhost" (TCP)

    # Trust all local connections (single-user dev machine).
    authentication = ''
      local all all              trust
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128      trust
    '';

    settings = {
      listen_addresses = lib.mkForce "localhost"; # loopback only, never 0.0.0.0

      # Logging with database name for filtering (mirrors darwin/postgres.nix).
      log_destination = "stderr";
      logging_collector = "on";
      log_directory = logDir;
      log_filename = "postgresql-%Y-%m-%d.log";
      log_rotation_age = "1d";
      log_rotation_size = "100MB";
      log_line_prefix = lib.mkForce "%t [%d] [%p] ";
      log_statement = "ddl";
      log_min_duration_statement = 1000;
      log_connections = "on";
      log_disconnections = "on";

      unix_socket_directories = dataDir;
    };
  };

  # Ensure log directory exists (matches darwin/postgres.nix).
  system.activationScripts.postgresLogDir.text = ''
    mkdir -p ${logDir}
    chown ${primaryUser} ${logDir}
  '';

  # No CLI package here: the psql/pg_dump CLIENT comes from the base
  # (common/packages.nix, postgresql_18). This module only runs the server.
}
