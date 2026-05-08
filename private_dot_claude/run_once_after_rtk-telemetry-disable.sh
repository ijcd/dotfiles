#!/usr/bin/env bash
set -euo pipefail
command -v rtk >/dev/null || exit 0
rtk telemetry disable >/dev/null
