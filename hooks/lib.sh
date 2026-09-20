# hooks/lib.sh — shared helpers for the precommit gates.

# gate_host FLAKE_DIR — the darwinConfigurations attr to gate THIS machine on.
#
# Was hardcoded "bearcat", which silently validated the WRONG machine: on
# blackbird (aarch64) every nix commit was checked against the x86_64 config,
# so broken arm64 nix passed and sound arm64 nix could fail. Resolve it the way
# scripts/bootstrap.sh does — named host if the flake defines one for this
# hostname, else the per-arch fallback, so an unnamed machine still gates.
# Override with NIX_GATE_HOST to check another host deliberately.
gate_host() {
  local flake_dir=$1 host arch
  host="${NIX_GATE_HOST:-$(scutil --get LocalHostName 2>/dev/null || hostname -s)}"
  [[ -n "${NIX_GATE_HOST:-}" ]] && { printf '%s' "$host"; return 0; }
  case "$(uname -m)" in
    arm64)  arch=aarch64-darwin ;;
    x86_64) arch=x86_64-darwin ;;
    *) echo "gate_host: unsupported arch: $(uname -m)" >&2; return 1 ;;
  esac
  if nix eval --json "${flake_dir}#darwinConfigurations" --apply builtins.attrNames 2>/dev/null \
       | tr -d '[]" ' | tr ',' '\n' | grep -qx "$host"; then
    printf '%s' "$host"
  else
    printf '%s' "$arch"
  fi
}
