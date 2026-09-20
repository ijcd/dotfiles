#!/usr/bin/env bash
# run_onchange_after_firefox-userjs.sh
#
# Writes Firefox user.js DNS-bypass block into every *.default-release* profile.
# Idempotent — marker-block replacement preserves any other user.js content.
# See docs/decisions/0001-local-dev-dns-layers.md.

set -euo pipefail

# ─── config ──────────────────────────────────────────────────────────────
# Add a TLD by appending to this list — it's permissive on purpose.
# Being on the list = Firefox skips DoH for that TLD's hostnames only.
EXCLUDED_DOMAINS="freedium.cfd, localhost, local, test, devip, lan, orb.local"
# 2 = DoH-with-system-fallback (privacy for public sites); 5 = DoH fully off.
TRR_MODE=2
# ─────────────────────────────────────────────────────────────────────────

BEGIN="// BEGIN chezmoi: DNS bypass (managed by run_onchange_after_firefox-userjs.sh)"
END="// END chezmoi: DNS bypass"

BLOCK=$(cat <<EOF
${BEGIN}
user_pref("network.trr.excluded-domains", "${EXCLUDED_DOMAINS}");
user_pref("network.trr.mode", ${TRR_MODE});
${END}
EOF
)

shopt -s nullglob
profiles=("$HOME/Library/Application Support/Firefox/Profiles/"*.default-release*/)
shopt -u nullglob

if [ ${#profiles[@]} -eq 0 ]; then
  echo "firefox-userjs: no *.default-release* profile found — skipping"
  exit 0
fi

for profile in "${profiles[@]}"; do
  userjs="${profile}user.js"
  [ -f "$userjs" ] || : > "$userjs"

  # Strip any existing chezmoi block, then re-append fresh.
  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { skip=1; next }
    skip && $0 == e { skip=0; next }
    !skip { print }
  ' "$userjs" > "${userjs}.tmp"

  [ -s "${userjs}.tmp" ] && printf '\n' >> "${userjs}.tmp"
  printf '%s\n' "$BLOCK" >> "${userjs}.tmp"
  mv "${userjs}.tmp" "$userjs"

  echo "firefox-userjs: wrote block to ${userjs}"
done
