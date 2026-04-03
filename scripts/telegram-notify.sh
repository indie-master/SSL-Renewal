#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/ssl-renewal/config.env"
[[ -f "$CONFIG" ]] || exit 0
# shellcheck disable=SC1090
source "$CONFIG"

MESSAGE="${1:-}"
[[ -n "$MESSAGE" ]] || exit 0
[[ "${TELEGRAM_ENABLED:-0}" == "1" ]] || exit 0
[[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]] || exit 0

curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"   -d "chat_id=${TELEGRAM_CHAT_ID}"   --data-urlencode "text=${MESSAGE}"   -d "parse_mode=HTML"   >/dev/null || true
