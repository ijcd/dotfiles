# jjflow-catchup.sh — catch the PRIVATE stack up to trunk, as a sourced module.
# Faithful to the original jj-catch-up (validate → SNAPSHOT → fetch → restack →
# restack-mine → refresh) with two changes: the rebase is parameterized by
# [jj-flow] base (FLOW_BASE) so a fleet can isolate onto test/main with one key,
# and a conflicted rebase is ROLLED BACK (jj op restore) instead of left
# rewritten-and-stuck. ijcd/* are never touched (they base-strip onto trunk, so
# they're not descendants of BASE). Needs jjflow-lib.sh + jjflow-refresh.sh sourced.

catchup_usage() {
  cat <<'EOF'
jj-flow catchup — fetch + rebase the private stack (base + wip/*) onto trunk,
then refresh workspaces. ijcd/* PR branches are left untouched.

Usage:
  jj-flow catchup            validate, snapshot WIP, fetch, rebase, refresh (skip WIP)
  jj-flow catchup -f         also refresh WIP workspaces
  jj-flow catchup -p         show full diffs for WIP workspaces (passed to refresh)
  jj-flow catchup -c         CHECK only: validate workspace paths, exit non-zero if broken

Base comes from [jj-flow] base (default local/main); point a fleet at test/main
with `jj config set --repo jj-flow.base test/main` to isolate its catch-up churn.
EOF
}

# The two rebase revsets, parameterized by BASE — exposed as functions so tests
# can assert they honor a base override without running a rebase.
catchup_private_root() { printf 'roots(%s..%s)' "$FLOW_TRUNK" "$FLOW_BASE"; }        # bottom of BASE's stack
catchup_mine()         { printf 'bookmarks() & descendants(%s..%s) ~ %s' "$FLOW_TRUNK" "$FLOW_BASE" "$FLOW_BASE"; }

catchup_ws_rows() { jj workspace list --ignore-working-copy -T 'name ++ "\t" ++ root ++ "\n"' 2>/dev/null; }

# catchup_broken_ws — names of workspaces whose recorded root path is unusable.
catchup_broken_ws() {
  local name root
  while IFS=$'\t' read -r name root; do
    [[ -n "$name" ]] || continue
    [[ -d "$root" ]] || printf '%s\n' "$name"
  done < <(catchup_ws_rows)
}

# catchup_snapshot — lock each reachable workspace's on-disk WIP into its @ BEFORE
# the rebase, so the rewrite carries it. jj refuses to snapshot a stale workspace,
# so that one is simply skipped (refresh/update-stale handles it after). This is
# the blind-spot guard: edits made while a workspace is ALREADY stale are lost, so
# snapshotting BEFORE the rewrite is the only safe moment.
catchup_snapshot() {
  local name root
  echo "== snapshot (lock WIP into @ before rewrite) =="
  while IFS=$'\t' read -r name root; do
    [[ -n "$name" ]] || continue
    if [[ ! -d "$root" ]]; then
      printf '  skip(bad-path) %s\n' "$name" >&2
    elif ( cd "$root" && jj status >/dev/null 2>&1 ); then
      printf '  snapshotted    %s\n' "$name"
    else
      printf '  stale          %s (refresh/update-stale will catch it)\n' "$name" >&2
    fi
  done < <(catchup_ws_rows)
}

catchup_main() {
  local force=0 check=0 patch=0
  while (( $# )); do
    case "$1" in
      -f|--force) force=1 ;;
      -c|--check) check=1 ;;
      -p|--patch) patch=1 ;;
      -h|--help)  catchup_usage; return 0 ;;
      *) echo "jj-flow catchup: unknown arg '$1'" >&2; return 2 ;;
    esac
    shift
  done
  flow_load_config

  # 1. validate workspaces — warn on any unreachable recorded path (they're skipped).
  local broken; broken=$(catchup_broken_ws)
  if [[ -n "$broken" ]]; then
    echo "jj-flow catchup: WARNING — unreachable workspace path(s); they will be SKIPPED:" >&2
    printf '%s\n' "$broken" | sed 's/^/    /' >&2
    echo "    repair: jj workspace forget <name>; jj workspace add --name <name> -r <bookmark> <real-path>" >&2
  fi
  if (( check )); then [[ -z "$broken" ]] || return 1; echo "all workspace paths resolve."; return 0; fi

  # 2. snapshot WIP into @ before we rewrite history.
  catchup_snapshot

  # 3. capture the op BEFORE any rewrite so a conflicted rebase can be fully undone
  # — a conflicted fleet member must not leave the shared stack rewritten-and-stuck.
  local pre_op; pre_op=$(jj op log --limit 1 --no-graph -T 'id ++ "\n"' 2>/dev/null | head -n1)
  [[ -n "$pre_op" ]] || { echo "jj-flow catchup: could not capture pre-rebase op id" >&2; return 1; }

  # 4. fetch. JJFLOW_CATCHUP_NO_FETCH skips the network fetch (test seam).
  [[ -n "${JJFLOW_CATCHUP_NO_FETCH:-}" ]] || jj git fetch \
    || { echo "jj-flow catchup: jj git fetch failed" >&2; return 1; }

  # 5. restack: lift base + wip as one unit onto trunk (ijcd/* aren't descendants
  # of BASE so they're untouched), then realign wip onto base.
  echo "== rebase private stack onto $FLOW_TRUNK =="
  local _catchup_rollback='jj op restore "$pre_op" >/dev/null 2>&1 || true'
  jj rebase -s "$(catchup_private_root)" -d "$FLOW_TRUNK" >/dev/null 2>&1 \
    || { echo "jj-flow catchup: restack failed; rolling back to op $pre_op" >&2; eval "$_catchup_rollback"; return 1; }
  jj rebase -b "$(catchup_mine)" -d "$FLOW_BASE" >/dev/null 2>&1 \
    || { echo "jj-flow catchup: restack-mine failed; rolling back to op $pre_op" >&2; eval "$_catchup_rollback"; return 1; }

  # 6. a conflict-bearing stack after rebase is a shared-history mess — ROLL BACK
  # so nothing is left rewritten, and tell the user to resolve on the old base first.
  if jj log --no-graph -r "($FLOW_BASE | descendants($FLOW_BASE)) & conflicts()" -T '"x"' 2>/dev/null | grep -q x; then
    echo "jj-flow catchup: STOPPED — rebase onto $FLOW_TRUNK would conflict; rolled back to op $pre_op (nothing rewritten)." >&2
    echo "  resolve the conflicting branch(es) on the current base, then re-run." >&2
    eval "$_catchup_rollback"
    return 3
  fi

  # 7. refresh every workspace onto the rewritten history (full refresh module:
  # state machine, WIP diff view, next-steps summary).
  local rf=(); (( force )) && rf+=(-f); (( patch )) && rf+=(-p)
  echo "== refresh workspaces =="
  JJRW_FIX_CMD="jj-flow catchup" refresh_main ${rf[@]+"${rf[@]}"}
}
