{ pkgs, config, primaryUser, ... }:
let
  dataDir = "/Users/${primaryUser}/.local/share/postgres";
  logDir = "${dataDir}/logs";
  pgVersion = pkgs.postgresql_17;

  # PostgreSQL configuration with per-database logging
  postgresConf = pkgs.writeText "postgresql.conf" ''
    # Connection
    listen_addresses = 'localhost'
    port = 5432
    unix_socket_directories = '${dataDir}'

    # Logging - include database name for filtering
    log_destination = 'stderr'
    logging_collector = on
    log_directory = '${logDir}'
    log_filename = 'postgresql-%Y-%m-%d.log'
    log_rotation_age = 1d
    log_rotation_size = 100MB

    # Format: timestamp [database] [pid] level:
    log_line_prefix = '%t [%d] [%p] '

    # What to log
    log_statement = 'ddl'
    log_min_duration_statement = 1000
    log_connections = on
    log_disconnections = on
  '';

  # Init script - creates data dir and initializes if needed
  initScript = pkgs.writeShellScript "postgres-init" ''
    set -e

    if [ ! -d "${dataDir}" ]; then
      echo "Creating data directory..."
      mkdir -p "${dataDir}"
    fi

    if [ ! -d "${logDir}" ]; then
      mkdir -p "${logDir}"
    fi

    if [ ! -f "${dataDir}/PG_VERSION" ]; then
      echo "Initializing PostgreSQL database..."
      ${pgVersion}/bin/initdb -D "${dataDir}" --no-locale --encoding=UTF8
    fi

    # Start postgres
    exec ${pgVersion}/bin/postgres -D "${dataDir}" -c config_file=${postgresConf}
  '';

in
{
  # Install postgres CLI tools
  environment.systemPackages = [
    pgVersion
    (pkgs.writeShellScriptBin "pg-start" ''
      launchctl bootout gui/$(id -u)/org.postgresql.dev 2>/dev/null || true
      launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/org.postgresql.dev.plist
      echo "PostgreSQL starting..."
      sleep 1
      ${pgVersion}/bin/pg_isready -h localhost && echo "PostgreSQL is ready" || echo "Waiting for PostgreSQL..."
    '')
    (pkgs.writeShellScriptBin "pg-stop" ''
      launchctl bootout gui/$(id -u)/org.postgresql.dev 2>/dev/null && echo "PostgreSQL stopped" || echo "PostgreSQL was not running"
    '')
    (pkgs.writeShellScriptBin "pg-status" ''
      ${pgVersion}/bin/pg_isready -h localhost
    '')
    (pkgs.writeShellScriptBin "pg-log" ''
      tail -f ${logDir}/postgresql-$(date +%Y-%m-%d).log
    '')
    (pkgs.writeShellScriptBin "pg-log-db" ''
      if [ -z "$1" ]; then
        echo "Usage: pg-log-db <database_name>"
        echo "   or: pg-log-db .  (uses BRANCH_PREFIX)"
        exit 1
      fi
      DB="$1"
      if [ "$DB" = "." ]; then
        DB="''${BRANCH_PREFIX:-main}"
      fi
      tail -f ${logDir}/postgresql-$(date +%Y-%m-%d).log | grep --line-buffered "\[$DB\]"
    '')
  ];

  # Launchd user agent
  launchd.user.agents.postgresql = {
    serviceConfig = {
      Label = "org.postgresql.dev";
      ProgramArguments = [ "${initScript}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardErrorPath = "${logDir}/launchd-stderr.log";
      StandardOutPath = "${logDir}/launchd-stdout.log";
      WorkingDirectory = dataDir;
    };
  };
}
