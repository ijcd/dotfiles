# jjflow-catchup.sh — catch the PRIVATE stack up to trunk, as a sourced module.
# Faithful to the original jj-catch-up (validate → SNAPSHOT → fetch → restack →
# restack-mine → refresh) with two changes: the rebase is parameterized by
# [jj-flow] base (FLOW_BASE) so a fleet can isolate onto test/main with one key,
# and a conflicted rebase of an OWNED branch is ROLLED BACK (jj op restore) instead of
# left rewritten-and-stuck — an off-base branch's conflict no longer rolls back my work
# (the restack + conflict gate are scoped to catchup_owned_wip). ijcd/* are never touched
# (they base-strip onto trunk, so they're not descendants of BASE). Needs jjflow-lib.sh +
# jjflow-refresh.sh sourced.

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

# The base-lift revset, parameterized by BASE — exposed as a function so tests can
# assert it honors a base override without running a rebase. The per-wip realignment
# is now driven by catchup_owned_wip (nearest-base ownership), not a blanket revset.
catchup_private_root() { printf 'roots(%s..%s)' "$FLOW_TRUNK" "$FLOW_BASE"; }        # bottom of BASE's stack

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

# catchup_wip_bookmarks — local wip-prefixed bookmark names, one per line. Drops
# remote-tracking and non-single-target rows (same guard as mirror's lister).
catchup_wip_bookmarks() {
  jj bookmark list -T 'if(remote,"",if(normal_target, name ++ "\n", ""))' 2>/dev/null \
    | while IFS= read -r name; do
        [[ -n "$name" && "$name" == "$FLOW_WORK_PREFIX"* ]] && printf '%s\n' "$name"
      done
}

# catchup_owned_wip — wip/* whose NEAREST local/main* ancestor is FLOW_BASE.
#  (1) descends from FLOW_BASE, and
#  (2) no other local/main* base lies strictly between FLOW_BASE and it.
# This is the per-branch ownership scoping d534ae3 gave the mirror verb, tightened to
# nearest-base so a tangled/legacy graph (old-style wip off shared main + new sibling
# bases) can't drag an off-base branch into my catchup. jj 0.43 treats a bare string
# pattern as EXACT, so we use bookmarks(glob:"local/main*") to catch every sibling base.
catchup_owned_wip() {
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    jj log --no-graph -r "($name) & descendants($FLOW_BASE)" -T '"x"' 2>/dev/null | grep -q x || continue
    jj log --no-graph \
       -r "(ancestors($name) ~ ancestors($FLOW_BASE)) & bookmarks(glob:\"local/main*\") ~ $FLOW_BASE" \
       -T '"x"' 2>/dev/null | grep -q x && continue   # another base sits between → not mine
    printf '%s\n' "$name"
  done < <(catchup_wip_bookmarks)
}

# catchup_guard_base — refuse to run against the bare shared base when the repo is a
# fleet (≥1 per-agent local/main-* base exists) but THIS workspace has none. Catching
# up the shared stack there drags every legacy/other-agent wip/* off it. Single-agent
# repos (no per-agent base anywhere) are unaffected: shared local/main is the intended
# base. The per-agent base itself is a sibling off trunk (jjf base fork duplicates the
# recipe onto trunk), so a resolved per-agent base already scopes catchup to my stream.
catchup_guard_base() {
  # Only the bare shared DEFAULT base is dangerous to catch up. A per-agent base
  # (local/main-*) OR an explicitly-configured isolation base (e.g. test/main via
  # jj-flow.base) is intentional — allow it. Nobody works canonical local/main directly.
  [[ "$FLOW_BASE" == "local/main" ]] || return 0
  # On the shared default base: only a fleet (some per-agent base exists) is dangerous.
  local peers
  peers=$(jj bookmark list -T 'if(remote,"",if(normal_target, name ++ "\n", ""))' 2>/dev/null \
            | grep -cE '^local/main-' || true)
  (( peers > 0 )) || return 0
  echo "jj-flow catchup: REFUSING — this workspace is on the shared '$FLOW_BASE' base," >&2
  echo "  but the repo has $peers per-agent base(s). Catching up here would drag every" >&2
  echo "  wip/* on the shared stack. Run 'jjf base fork' to mint local/main-$FLOW_WS," >&2
  echo "  then re-run catchup (it will touch only your stream)." >&2
  return 4
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
  catchup_guard_base || return $?

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

  # 5. restack, SCOPED to the branches this base owns. Lift my base onto trunk (a
  # per-agent base is a sibling off trunk, so -s roots(TRUNK..BASE) carries only my
  # line), then realign each OWNED wip onto the advanced base. Off-base wip/* — other
  # agents' sibling streams, legacy branches on shared main — are never rebased.
  # LIMITATION: a NESTED non-owned sub-base chained UNDER my base (unusual — base fork
  # mints siblings off trunk, not children) still rides the -s lift; the owned-scoped
  # gate below won't roll back for its conflict, so it may be left rebased-and-conflicted
  # for its owner to resolve. The common sibling topology is unaffected.
  echo "== rebase private stack onto $FLOW_TRUNK (owned wip only) =="
  local _catchup_rollback='jj op restore "$pre_op" >/dev/null 2>&1 || true'
  jj rebase -s "$(catchup_private_root)" -d "$FLOW_TRUNK" >/dev/null 2>&1 \
    || { echo "jj-flow catchup: restack failed; rolling back to op $pre_op" >&2; eval "$_catchup_rollback"; return 1; }

  local owned; owned=$(catchup_owned_wip)
  local w
  while IFS= read -r w; do
    [[ -n "$w" ]] || continue
    jj rebase -b "$w" -d "$FLOW_BASE" >/dev/null 2>&1 \
      || { echo "jj-flow catchup: restack of $w failed; rolling back to op $pre_op" >&2; eval "$_catchup_rollback"; return 1; }
  done <<< "$owned"

  # 6. conflict gate SCOPED to base + owned wip only — an off-base branch's conflict
  # must not roll back my clean catch-up (the all-or-nothing bug).
  local gate="$FLOW_BASE"
  while IFS= read -r w; do [[ -n "$w" ]] && gate="$gate | $w"; done <<< "$owned"
  if jj log --no-graph -r "($gate) & conflicts()" -T '"x"' 2>/dev/null | grep -q x; then
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
