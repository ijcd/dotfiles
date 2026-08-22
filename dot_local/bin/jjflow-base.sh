# jjflow-base.sh — per-agent private base management, as a sourced module.
# `local/main-<workspace>` is an agent's own copy of the canonical recipe
# (trunk()..local/main) on trunk. Needs jjflow-lib.sh sourced (flow_load_config,
# flow_current_workspace, FLOW_TRUNK).

base_usage() {
  cat <<'EOF'
jj-flow base — manage per-agent private bases (local/main-<workspace>).

Usage:
  jj-flow base fork    mint local/main-<this-workspace> from the canonical recipe
                       (trunk()..local/main) on trunk. Idempotent.
  jj-flow base list    list every local/main-* base and its drift from trunk.

Each agent works off its own base so catch-up/mirror touch only that agent's
stream. Nobody works on the canonical local/main directly.
EOF
}

# base_fork — mint local/main-<W> = the canonical recipe duplicated onto trunk.
base_fork() {
  flow_load_config
  local w="$FLOW_WS"
  [[ -n "$w" ]] || { echo "jj-flow base: could not determine the current workspace" >&2; return 2; }
  local bm="local/main-$w"
  if jj log --no-graph -r "$bm" -T '""' >/dev/null 2>&1; then
    echo "jj-flow base: $bm already exists (use catchup to advance it)"; return 0
  fi
  # Duplicate the whole recipe stack onto trunk, preserving the commits; bookmark
  # the tip. flow_load_config left FLOW_BASE=local/main here (the bookmark doesn't
  # exist yet), which is the canonical recipe source.
  local out tip
  out=$(jj duplicate "$FLOW_TRUNK..local/main" --destination "$FLOW_TRUNK" 2>&1) \
    || { echo "jj-flow base: duplicate of recipe onto $FLOW_TRUNK failed" >&2; printf '%s\n' "$out" >&2; return 1; }
  tip=$(printf '%s\n' "$out" | awk '/^Duplicated/{c=$5} END{print c}')
  [[ -n "$tip" ]] || { echo "jj-flow base: empty recipe ($FLOW_TRUNK..local/main) — nothing to fork" >&2; return 1; }
  jj bookmark set "$bm" -r "$tip" >/dev/null 2>&1 \
    || { echo "jj-flow base: bookmark set failed for $bm" >&2; return 1; }
  echo "jj-flow base: forked $bm from local/main onto $FLOW_TRUNK"
}

# base_list — each local/main* base and how far it trails trunk.
base_list() {
  flow_load_config
  local name n
  jj bookmark list -T 'if(remote, "", if(normal_target, name ++ "\n", ""))' 2>/dev/null \
    | grep -E '^local/main($|-)' | sort | while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      n=$(jj log --no-graph -r "$name..$FLOW_TRUNK" -T '"x\n"' 2>/dev/null | grep -c x || true)
      if [[ "${n:-0}" -eq 0 ]]; then printf '  %-28s ✓ current\n' "$name"
      else printf '  %-28s ⟳ %d behind %s\n' "$name" "$n" "$(flow_render_root "$FLOW_TRUNK")"; fi
    done
}

base_main() {
  case "${1:-}" in
    fork)        shift; base_fork "$@" ;;
    list|"")     shift 2>/dev/null || true; base_list ;;
    -h|--help)   base_usage ;;
    *) echo "jj-flow base: unknown subcommand '$1'" >&2; base_usage >&2; return 2 ;;
  esac
}
