# _jjflow_testwrap.sh — shared test helper. jj-flow retired the standalone shims
# (jj-mirror, jj-catch-up, …), so each suite drives its module directly: a tiny
# generated wrapper sources the module(s) and calls the tool's <tool>_main, RAW —
# not via `jjf`, whose FLOW_BASE→JJ_MIRROR_SOURCE_ROOT export would clobber tests
# that set the source root themselves. Replaces the deleted executable_jj-<tool>.

_JJFLOW_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dot_local/bin" && pwd)"

# flow_make_wrapper "<module.sh ...>" <main-fn> [set-flags] → prints a temp exe path.
flow_make_wrapper() {
  local mods=$1 mainfn=$2 flags="${3:-uo}" w m
  w="$(mktemp "${TMPDIR:-/tmp}/jjflow-testwrap.XXXXXX")"
  {
    echo '#!/usr/bin/env bash'
    echo "set -${flags} pipefail"
    for m in $mods; do echo "source \"$_JJFLOW_BIN/$m\""; done
    echo "$mainfn \"\$@\""
  } > "$w"
  chmod +x "$w"
  printf '%s' "$w"
}
