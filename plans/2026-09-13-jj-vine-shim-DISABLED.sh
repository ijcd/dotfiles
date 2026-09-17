#!/usr/bin/env bash
# jj-vine — thin PATH shim that keeps the GitHub token OUT of jj config on disk.
#
# WHY: jj-vine 0.5.3 reads its forge token ONLY from jj config (jj-vine.<forge>.token,
# set via `jj config set --repo`). No env var, no keychain (verified against the
# binary). So the token normally sits plaintext in .jj/repo/config.toml, dumpable by
# any process via `jj config list`. This shim vends the token gh already keeps in the
# macOS keyring (`gh auth token`), writes it to an ephemeral 0600 temp file, and layers
# that file onto the USER config via JJ_CONFIG — so nothing plaintext persists in the repo.
#
# jj config layering (jj 0.43, verified): a colon-list JJ_CONFIG stacks each file and
# PRESERVES the real user config (a single-file JJ_CONFIG would REPLACE it and drop
# aliases). Precedence is user(JJ_CONFIG) < repo, so the injected token only takes effect
# once the repo-scope token is removed — see the one-time migration the shim nudges below.
#
# Fails OPEN: if gh has no token, or the real jj-vine can't be found, it execs the real
# binary unchanged — never worse than today.
#
# REQUIRES: ~/.local/bin ahead of the nix profile in PATH (it is) so this intercepts.
# One-time per clone, to actually drop the plaintext:  jj config unset --repo jj-vine.github.token
set -uo pipefail

# Resolve the real jj-vine — the next one on PATH that isn't this shim.
self="$(command -v -- "$0" 2>/dev/null || printf '%s' "$0")"
selfdir="$(cd "$(dirname "$self")" && pwd -P)"
real=""
IFS=: read -ra _dirs <<< "$PATH"
for _d in "${_dirs[@]}"; do
  [[ -z "$_d" || "$(cd "$_d" 2>/dev/null && pwd -P)" == "$selfdir" ]] && continue
  if [[ -x "$_d/jj-vine" ]]; then real="$_d/jj-vine"; break; fi
done
[[ -n "$real" ]] || { echo "jj-vine shim: real jj-vine not found on PATH" >&2; exit 127; }

# No gh token available → run real jj-vine unchanged (existing config-token flow).
token="$(gh auth token 2>/dev/null || true)"
[[ -n "$token" ]] || exec "$real" "$@"

# Nudge (once per repo) if a plaintext repo-scope token still shadows the injection.
# Repo config outranks the user layer, so until it's unset the injected token is ignored.
if jj config list --repo 2>/dev/null | grep -q '^jj-vine\.github\.token'; then
  echo "jj-vine shim: plaintext token still in .jj/repo/config.toml — it shadows the keyring token." >&2
  echo "             drop it once with:  jj config unset --repo jj-vine.github.token" >&2
fi

# Ephemeral 0600 token file, layered onto the real user config via a colon-list.
tokfile="$(mktemp "${TMPDIR:-/tmp}/jj-vine-tok.XXXXXX")" || exec "$real" "$@"
chmod 600 "$tokfile"
# Clean up on ANY exit path. NOTE: must NOT `exec` jj-vine below — exec replaces this
# process and the trap would never fire, leaking the plaintext token file every run.
trap 'rm -f "$tokfile"' EXIT INT TERM HUP
printf '[jj-vine.github]\ntoken = "%s"\n' "$token" > "$tokfile"

base="${JJ_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/jj/config.toml}"
export JJ_CONFIG="$base:$tokfile"

# Run as a child (not exec) so the trap runs and the token file is removed. Propagate
# jj-vine's exit code unchanged.
"$real" "$@"; rc=$?
exit "$rc"
