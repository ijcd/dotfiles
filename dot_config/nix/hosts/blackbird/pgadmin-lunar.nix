# Lunar pgAdmin connection — blackbird only (home-manager module).
#
# Declarative pgAdmin4 server definition for the local lunar-dev cluster
# (~/pgsql/lunar-18, see ../blackbird/lunar-dev.nix). pgAdmin4 is the desktop
# app (homebrew cask) and stores connections in a stateful SQLite db, so there
# is no purely-declarative way to inject them. Instead this ships:
#   1. the connection as ~/.config/pgadmin/lunar-servers.json (source of truth)
#   2. `pgadmin-load-lunar`, an idempotent importer that loads (1) into pgAdmin.
# Run `pgadmin-load-lunar` once with pgAdmin quit to seed; re-run after edits.
#
# Connects as the cluster superuser `ijcd` (loopback trust auth → no password),
# so pgAdmin has full admin visibility. To use the app role instead, change
# Username to "postgres". MaintenanceDB "postgres" surfaces every DB in the
# cluster under the one server (new_quin_dev, lunar_portal_dev, lunar_vault_dev,
# fdb, and the *_test dbs).
{ pkgs, ... }:
{
  home.file.".config/pgadmin/lunar-servers.json".text = builtins.toJSON {
    Servers."1" = {
      Name = "Lunar (local PG18)";
      Group = "Lunar";
      Host = "localhost";
      Port = 5432;
      MaintenanceDB = "postgres";
      Username = "ijcd";
      SSLMode = "prefer";
      Comment = "nix-managed (blackbird). lunar-dev cluster at ~/pgsql/lunar-18.";
    };
  };

  home.packages = [
    (pkgs.writeShellScriptBin "pgadmin-load-lunar" ''
      set -eu
      json="$HOME/.config/pgadmin/lunar-servers.json"
      app="/Applications/pgAdmin 4.app"
      setup="$app/Contents/Resources/web/setup.py"
      py=$(ls "$app/Contents/Frameworks/Python.framework/Versions/"*/bin/python3.[0-9]* 2>/dev/null \
             | grep -v 'config$' | head -1)
      [ -n "''${py:-}" ] && [ -f "$setup" ] || { echo "pgAdmin 4 not installed at $app" >&2; exit 1; }
      if pgrep -fi 'pgadmin 4' >/dev/null 2>&1; then
        echo "Quit pgAdmin 4 first (it locks its config DB), then re-run pgadmin-load-lunar." >&2
        exit 1
      fi
      "$py" "$setup" load-servers "$json" --user pgadmin4@pgadmin.org
      echo "✓ imported $json — relaunch pgAdmin to see 'Lunar (local PG18)' under the Lunar group."
    '')
  ];
}
