# jjflow-tug.sh — jj-tug logic as a SOURCED module. usage → tug_usage to clear
# jj-flow's namespace. tug_main does `set +e` because `jj bookmark move`
# legitimately returns non-zero (nothing to move / would rewind), handled per-line
# — so it works whether sourced into jj-flow (set -e) or run via the thin entry.
tug_usage() {
  cat <<'EOF'
jj-tug — advance the nearest bookmark up to @- (the classic `jj tug`), in the
current workspace or every workspace, optionally scoped to a bookmark glob.

Usage:
  jj-tug [GLOB]            tug the current workspace's @- (any bookmark, or GLOB)
  jj-tug --all [GLOB]      tug EVERY workspace's @-; GLOB defaults to wip/*
  jj-tug --help

Notes:
  - Nearest bookmark = heads(::<@-> & bookmarks[glob]) — the label at-or-behind
    your last real commit.
  - Forward-only: a bookmark at (or ahead of) @- is left alone.
  - --all addresses each workspace as `<ws>@` (no cd; reads the recorded @, so a
    stale workspace is tugged without `jj workspace update-stale`).
  - The glob is a safety rail: `--all wip/*` never drags local/main or a mirror
    along — a workspace with no matching bookmark behind @- is skipped.
EOF
}

# tug_one AT GLOB LABEL — move the nearest (GLOB-scoped) bookmark at-or-behind AT
# up to AT. Empty GLOB = any bookmark. Prints one status line; never aborts.
tug_one() {
  local at=$1 glob=$2 label=$3
  local scope from name at_cid from_cid out rc new
  if [[ -n "$glob" ]]; then scope="bookmarks(glob:\"$glob\")"; else scope="bookmarks()"; fi
  from="heads((::$at) & $scope)"

  name=$(jj log --no-graph -r "$from" -T 'local_bookmarks.map(|b| b.name()).join(",")' 2>/dev/null | head -n1)
  if [[ -z "$name" ]]; then
    printf '%s: no %s behind @- (skipped)\n' "$label" "${glob:-bookmark}"
    return 0
  fi
  at_cid=$(jj log --no-graph -r "$at" -T 'commit_id.short()' 2>/dev/null | head -n1)
  from_cid=$(jj log --no-graph -r "$from" -T 'commit_id.short()' 2>/dev/null | head -n1)
  if [[ -z "$at_cid" ]]; then
    printf '%s: no @- to tug to (skipped)\n' "$label"; return 0
  fi
  if [[ "$from_cid" == "$at_cid" ]]; then
    printf '%s: %s already at @- (skipped)\n' "$label" "$name"; return 0
  fi
  out=$(jj bookmark move --from "$from" --to "$at" 2>&1); rc=$?
  if (( rc == 0 )); then
    new=$(jj log --no-graph -r "$at" -T 'commit_id.short()' 2>/dev/null | head -n1)
    printf '%s: tugged %s -> %s\n' "$label" "$name" "$new"
  else
    printf '%s: %s not moved (%s)\n' "$label" "$name" "$(printf '%s' "$out" | head -n1 | sed 's/^Error: //')"
  fi
  return 0
}
tug_main() {
  set +e   # jj bookmark move returns non-zero legitimately; handled per-line
  local all=0 glob="" line ws
while (( $# )); do
  case "$1" in
    --all)      all=1; shift ;;
    -h|--help)  tug_usage; exit 0 ;;
    --*)        echo "jj-tug: unknown flag '$1'" >&2; exit 2 ;;
    *)          glob="$1"; shift ;;
  esac
done

if (( all )); then
  [[ -n "$glob" ]] || glob="wip/*"
  jj workspace list 2>/dev/null | while IFS= read -r line; do
    ws="${line%%:*}"
    [[ -n "$ws" ]] || continue
    tug_one "${ws}@-" "$glob" "$ws"
  done
else
  tug_one "@-" "$glob" "@"
fi
}
