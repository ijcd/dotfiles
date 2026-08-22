# jjflow-refresh.sh — jj-refresh-workspaces as a SOURCED module. Faithful port of
# the POSIX script: refresh stale workspaces after a history rewrite, skip (and
# show) WIP ones by default, end with a brew-doctor "next steps" summary.
# usage → refresh_usage (heredoc, since the awk-$0 self-doc breaks when sourced).

refresh_usage() {
  cat <<'EOF'
jj-refresh-workspaces — refresh stale jj workspaces after a history rewrite,
showing (and by default skipping) any with work in progress.

  refresh            refresh clean workspaces; SKIP WIP ones, showing a --stat
  refresh -p         for WIP workspaces, show the full diff (-p/--patch)
  refresh -f         ALSO refresh WIP workspaces (-f/--force)

Per workspace:
  * @ empty                -> jj workspace update-stale (no-op if current)
  * @ has changes, CURRENT -> ok (has WIP): left as-is
  * @ has changes, STALE   -> default: skip + show diff (run -f to refresh)
                              --force: update-stale rebases it; a clash becomes an
                              in-commit conflict, never a loss (jj op restore undoes).
EOF
}

# _refresh_show_wip ROOT SHOW — a WIP workspace's recorded @ change: --stat, or full
# diff with SHOW=patch. cd in so paths render workspace-relative.
_refresh_show_wip() {
  local root=$1 show=$2
  if [[ "$show" == patch ]]; then
    ( cd "$root" && jj --ignore-working-copy diff -r @ ) 2>/dev/null | sed 's/^/               /'
  else
    ( cd "$root" && jj --ignore-working-copy diff -r @ --stat ) 2>/dev/null | sed 's/^/               /'
  fi
}

refresh_main() {
  local show=stat force=0
  while (( $# )); do
    case "$1" in
      -p|--patch) show=patch ;;
      -f|--force) force=1 ;;
      -h|--help)  refresh_usage; return 0 ;;
      --) shift; break ;;
      -*) printf 'refresh: unknown option: %s\n' "$1" >&2; return 2 ;;
      *) break ;;
    esac
    shift
  done

  # The command to suggest for the -f re-run (jj-flow catchup overrides via env).
  local fix_cmd="${JJRW_FIX_CMD:-jj-refresh-workspaces}"

  local ws_list
  ws_list=$(jj workspace list --ignore-working-copy -T 'name ++ "\t" ++ root ++ "\n"' 2>/dev/null) || {
    echo "refresh: run this from inside a jj repo/workspace." >&2; return 1; }
  [[ -n "$ws_list" ]] || { echo "refresh: no workspaces found." >&2; return 1; }

  local bad_path="" wip_stale="" wip_current=""   # accumulators for the summary
  local name root stale state out
  # process substitution keeps the accumulators in this shell (a pipe would not).
  while IFS=$'\t' read -r name root; do
    [[ -n "${name:-}" ]] || continue
    if [[ ! -d "$root" ]]; then
      printf '  skip(bad-path) %-28s %s\n' "$name" "$root" >&2
      bad_path="$bad_path $name"; continue
    fi
    # Best-effort snapshot (captures on-disk edits into @ when current); jj refuses
    # to snapshot a STALE workspace, so success/failure doubles as the stale check.
    if ( cd "$root" && jj status >/dev/null 2>&1 ); then stale=0; else stale=1; fi
    state=$( cd "$root" && jj --ignore-working-copy log --no-graph -r @ -T 'if(empty, "clean", "wip")' 2>/dev/null || echo err )
    case "$state" in
      err)
        printf '  skip(?)    %-28s could not read @ (dead? `jj workspace forget %s`)\n' "$name" "$name" >&2 ;;
      clean)
        out=$( cd "$root" && jj workspace update-stale 2>&1 || true )
        case "$out" in
          *"not stale"*|*"Nothing changed"*|"") printf '  ok         %-28s up to date\n' "$name" ;;
          *)                                     printf '  refreshed  %-28s\n' "$name" ;;
        esac ;;
      wip)
        if [[ "$stale" -eq 0 ]]; then
          printf '  ok         %-28s up to date (has WIP)\n' "$name"
          wip_current="$wip_current $name"
        elif [[ "$force" -eq 1 ]]; then
          printf '  refreshed  %-28s (was stale + WIP -- rebased onto refresh)\n' "$name"
          _refresh_show_wip "$root" "$show"
          ( cd "$root" && jj workspace update-stale 2>&1 | sed 's/^/               /' ) || true
        else
          printf '  skip(WIP,stale) %-24s stale with changes -- run -f to refresh:\n' "$name" >&2
          _refresh_show_wip "$root" "$show"
          wip_stale="$wip_stale $name"
        fi ;;
    esac
  done < <(printf '%s\n' "$ws_list")

  # next steps (brew-doctor style)
  local conflicted w c
  conflicted=$(jj log --no-graph -r 'conflicts()' -T 'change_id.shortest() ++ " "' 2>/dev/null || true)
  if [[ -n "$bad_path$wip_stale$wip_current" || -n "$conflicted" ]]; then
    echo; echo "next steps:"
    if [[ -n "$bad_path" ]]; then
      echo "  * broken workspace path (unreachable) -- forget + re-add:"
      for w in $bad_path; do echo "        $w"; done
      echo "      \$ jj workspace forget <name> && jj workspace add --name <name> -r <bookmark> <path>"; echo
    fi
    if [[ -n "$wip_stale" ]]; then
      echo "  * stale + uncommitted work (not refreshed):"
      for w in $wip_stale; do echo "        $w"; done
      echo "      \$ $fix_cmd -f"; echo
    fi
    if [[ -n "$wip_current" ]]; then
      echo "  * uncommitted work parked in @ -- commit or discard when ready:"
      for w in $wip_current; do echo "        $w"; done
      echo "      \$ cd <ws> && jj commit -m '...'   # keep"
      echo "      \$ cd <ws> && jj restore <path>    # drop"; echo
    fi
    if [[ -n "$conflicted" ]]; then
      echo "  * conflicted commit(s) present -- resolve:"
      for c in $conflicted; do echo "        $c"; done
      echo "      \$ jj log -r 'conflicts()'         # then edit files / jj resolve"; echo
    fi
  else
    echo; echo "all workspaces clean and current -- nothing to do."
  fi
}
