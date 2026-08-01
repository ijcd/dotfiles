# use_claude <profile> — point Claude Code at a per-account config dir.
#
# Sets CLAUDE_CONFIG_DIR=~/.claude-<profile>, giving that shell (and any claude
# launched from it) its own login + history, isolated from the default ~/.claude.
# See ~/.claude-ijcd (personal) vs ~/.claude (work, the default). Each config dir
# needs its own one-time `/login`; the shared config (settings/skills/CLAUDE.md)
# is symlinked in via private_dot_claude-ijcd/.
#
# direnv auto-sources every ~/.config/direnv/lib/*.sh, so `use claude <profile>`
# is available in any .envrc. Usage in an .envrc:  use claude ijcd
use_claude() {
  local profile="${1:?use_claude: need a profile name, e.g. \`use claude ijcd\`}"
  export CLAUDE_CONFIG_DIR="$HOME/.claude-${profile}"
}
