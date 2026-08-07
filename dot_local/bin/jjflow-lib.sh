# jjflow-lib.sh — shared library for the jj-flow porcelain (sourced, not executed).
# Owns the model the jj-* tools re-derive independently: config, layer revsets,
# branch-state classification, workspace listing, live-PR detection.
#
# Config resolution reads [jj-flow] first, falling back to the legacy
# [jj-mirror]/[jj-integrate] keys during migration so nothing breaks mid-flight.
#
# See docs/superpowers/specs/2026-08-06-jj-flow-unified-tool-design.md.

# _cfg KEY DEFAULT [FALLBACK_KEY...] — first present of jj-flow.KEY, then each
# FALLBACK_KEY, else DEFAULT.
_cfg() {
  local key=$1 def=$2 v; shift 2
  v=$(jj config get "jj-flow.$key" 2>/dev/null) && { printf '%s' "$v"; return; }
  local fk
  for fk in "$@"; do
    v=$(jj config get "$fk" 2>/dev/null) && { printf '%s' "$v"; return; }
  done
  printf '%s' "$def"
}

# flow_require_repo — hard-fail outside a jj repo instead of rendering a fake,
# empty stack (every jj call silently errors → raw-revset labels + blank cids).
flow_require_repo() {
  jj root >/dev/null 2>&1 || {
    echo "jj-flow: not a jj repo here — run inside your jj workspace (e.g. ~/work/lunar/<name>)" >&2
    exit 1
  }
}

flow_load_config() {
  flow_require_repo
  FLOW_TRUNK=$(_cfg trunk 'trunk()' 'jj-mirror.prime-root')
  FLOW_BASE=$(_cfg base 'local/main' 'jj-mirror.source-root' 'jj-integrate.base')
  FLOW_WORK_PREFIX=$(_cfg work-prefix 'wip/' 'jj-mirror.source-prefix')
  FLOW_PR_PREFIX=$(_cfg pr-prefix 'pr/' 'jj-mirror.prime-prefix')
  FLOW_INTEGRATION=$(_cfg integration 'local/integration' 'jj-integrate.bookmark')
  FLOW_WS_DIR=$(_cfg workspace-dir '' )
  FLOW_REMOTE=$(_cfg remote 'origin')
}

# flow_cid REV — short commit id of REV, or empty.
flow_cid() { jj log --no-graph -r "$1" -T 'commit_id.short() ++ "\n"' 2>/dev/null | head -n1 || true; }

# flow_render_root REVSET — a friendly label: the local bookmark on the commit
# REVSET resolves to, else the revset as written (so trunk() → "master").
flow_render_root() {
  local bm
  bm=$(jj log --no-graph -r "$1" -T 'local_bookmarks.map(|b| b.name()).join(",")' 2>/dev/null | head -n1)
  [[ -n "$bm" ]] && printf '%s' "$bm" || printf '%s' "$1"
}

# flow_wip_branches — one "<name>\t<short-cid>" per work-prefix bookmark (local,
# single-target, non-remote), sorted by name.
flow_wip_branches() {
  jj bookmark list -T 'if(remote, "", if(normal_target, name ++ "\t" ++ normal_target.commit_id().short() ++ "\n", ""))' 2>/dev/null \
    | awk -v p="$FLOW_WORK_PREFIX" 'index($0,p)==1' | sort
}

# flow_strip_work NAME — NAME minus the work prefix (wip/foo → foo).
flow_strip_work() { printf '%s' "${1#"$FLOW_WORK_PREFIX"}"; }
# flow_pr_name SUFFIX — the PR bookmark name for a suffix (foo → ijcd/foo).
flow_pr_name() { printf '%s%s' "$FLOW_PR_PREFIX" "$1"; }

# ─── PR-state detection (memoized; injectable for tests) ─────────────────────────
# Open and merged dest-bookmark sets. Env seams JJ_MIRROR_LIVE_PRS (open, shared
# with jj-mirror) and JJFLOW_MERGED_PRS (merged) short-circuit the gh call so the
# test harness needs no network. Resolvers run in-process (call as plain commands,
# not in $()/pipes) so the memo persists across branches in one status render.
_FLOW_OPEN=""; _FLOW_OPEN_DONE=0
_flow_resolve_open() {
  (( _FLOW_OPEN_DONE )) && return 0
  if [[ -n "${JJ_MIRROR_LIVE_PRS+x}" ]]; then
    # shellcheck disable=SC2086
    _FLOW_OPEN=$(printf '%s\n' $JJ_MIRROR_LIVE_PRS | awk 'NF')
  elif command -v gh >/dev/null 2>&1; then
    _FLOW_OPEN=$(gh pr list --state open --json headRefName -q '.[].headRefName' 2>/dev/null | awk 'NF' || true)
  fi
  _FLOW_OPEN_DONE=1
}
_FLOW_MERGED=""; _FLOW_MERGED_DONE=0
_flow_resolve_merged() {
  (( _FLOW_MERGED_DONE )) && return 0
  if [[ -n "${JJFLOW_MERGED_PRS+x}" ]]; then
    # shellcheck disable=SC2086
    _FLOW_MERGED=$(printf '%s\n' $JJFLOW_MERGED_PRS | awk 'NF')
  elif command -v gh >/dev/null 2>&1; then
    _FLOW_MERGED=$(gh pr list --state merged --json headRefName -q '.[].headRefName' 2>/dev/null | awk 'NF' || true)
  fi
  _FLOW_MERGED_DONE=1
}
flow_pr_open()   { _flow_resolve_open;   printf '%s\n' "$_FLOW_OPEN"   | grep -qxF "$1"; }
flow_pr_merged() { _flow_resolve_merged; printf '%s\n' "$_FLOW_MERGED" | grep -qxF "$1"; }

# flow_branch_collides WIP — true (0) if a base divergence exists: some file
# differs between trunk (PR base) and base (private base) AND is touched by WIP.
# Such a file makes WIP's diff un-matchable on the PR base — the "stuck" case
# (mirrors jj-mirror's thread_collisions).
flow_branch_collides() {
  local wip=$1
  comm -12 \
    <(jj diff --name-only --from "$FLOW_TRUNK" --to "$FLOW_BASE" 2>/dev/null | sort -u) \
    <(jj diff --name-only --from "$FLOW_BASE" --to "$wip"        2>/dev/null | sort -u) \
  | grep -q .
}

# flow_collision_files WIP — "<file>\t<cause>" per base-divergence file (drives
# the stuck note). cause: `base` = the private base's own commits edit it (fold
# in or drop from base); `lag` = only trunk moved ahead (catch-up realigns).
flow_collision_files() {
  local wip=$1 f
  comm -12 \
    <(jj diff --name-only --from "$FLOW_TRUNK" --to "$FLOW_BASE" 2>/dev/null | sort -u) \
    <(jj diff --name-only --from "$FLOW_BASE" --to "$wip"        2>/dev/null | sort -u) \
  | while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      if jj log --no-graph -r "$FLOW_TRUNK..$FLOW_BASE & files(\"$f\")" -T '"x"' 2>/dev/null | grep -q x; then
        printf '%s\tbase\n' "$f"
      else
        printf '%s\tlag\n' "$f"
      fi
    done
}

# flow_branch_state WIP — one of: draft | mirrored | live | stuck | merged.
#   draft    no PR bookmark yet
#   merged   its PR is merged (terminal → cleanup candidate)
#   stuck    PR exists but a base divergence blocks a clean sync
#   live     PR is open
#   mirrored PR bookmark exists, not pushed / no open PR
flow_branch_state() {
  local wip=$1 sfx pr
  sfx=$(flow_strip_work "$wip"); pr=$(flow_pr_name "$sfx")
  if [[ -z "$(flow_cid "$pr")" ]]; then printf 'draft'; return; fi
  if flow_pr_merged "$pr"; then printf 'merged'; return; fi
  if flow_branch_collides "$wip"; then printf 'stuck'; return; fi
  if flow_pr_open "$pr"; then printf 'live'; return; fi
  printf 'mirrored'
}

# flow_branch_drift WIP — how far the branch trails trunk: "even" or "N behind"
# (N = trunk commits not in WIP's ancestry).
flow_branch_drift() {
  local wip=$1 n
  n=$(jj log --no-graph -r "$wip..$FLOW_TRUNK" -T '"x\n"' 2>/dev/null | grep -c x || true)
  if [[ "${n:-0}" -eq 0 ]]; then printf 'even'; else printf '%d behind' "$n"; fi
}

# flow_glyph STATE — the pipeline glyph for a state.
flow_glyph() {
  case "$1" in
    draft)    printf '○' ;;
    mirrored) printf '◐' ;;
    live)     printf '●' ;;
    stuck)    printf '⚠' ;;
    merged)   printf '✓' ;;
    *)        printf '?' ;;
  esac
}

# flow_ws_for WIP — "<token>\t<health>" for the workspace backing WIP, mapped by
# workspace-dir/<suffix>. health ∈ none|missing|wip|ok. token is the suffix (or —).
flow_ws_for() {
  local wip=$1 sfx dir
  sfx=$(flow_strip_work "$wip")
  if [[ -z "$FLOW_WS_DIR" ]]; then printf '%s\t%s' '—' 'none'; return; fi
  dir="${FLOW_WS_DIR/#\~/$HOME}/$sfx"
  if [[ ! -d "$dir" ]]; then printf '%s\t%s' '—' 'none'; return; fi
  # WIP if the workspace @ has uncommitted, non-empty content beyond its parent.
  if ( cd "$dir" && jj log --no-graph -r '@ & ~empty()' -T '"x"' 2>/dev/null | grep -q x ); then
    printf '%s\t%s' "$sfx" 'wip'
  else
    printf '%s\t%s' "$sfx" 'ok'
  fi
}
