#!/bin/bash
# Bootstrap macOS Keychain entry for ~/.authinfo Groq API key.
# Idempotent: skips silently if entry already exists.
# Interactive: prompts when stdin/stdout are a terminal; skips with hint otherwise.

set -euo pipefail
[[ "$(uname)" == "Darwin" ]] || exit 0

SERVICE="authinfo-groq"
ACCOUNT="$(id -un)"

# already configured? silent exit
if /usr/bin/security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w >/dev/null 2>&1; then
  exit 0
fi

# non-interactive run? skip with a hint
if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
  echo "[authinfo-keychain] no '$SERVICE' Keychain entry; skipping (non-interactive)." >&2
  echo "[authinfo-keychain] set later: security add-generic-password -s $SERVICE -a \$USER -w 'gsk_...' -T /usr/bin/security -U" >&2
  exit 0
fi

echo
echo "Set up Groq API key in Keychain (service: $SERVICE)"
echo "Press Enter with empty input to skip."
read -rsp "Groq API key (gsk_...): " API_KEY
echo

if [[ -z "$API_KEY" ]]; then
  echo "[authinfo-keychain] skipped (empty input)" >&2
  exit 0
fi

/usr/bin/security add-generic-password \
  -s "$SERVICE" \
  -a "$ACCOUNT" \
  -w "$API_KEY" \
  -T /usr/bin/security \
  -U

echo "[authinfo-keychain] stored in Keychain (service=$SERVICE)"
