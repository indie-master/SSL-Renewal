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

CURL_ARGS=(
  -fsS
  -X POST
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
  -d "chat_id=${TELEGRAM_CHAT_ID}"
  --data-urlencode "text=${MESSAGE}"
  -d "parse_mode=HTML"
)

if [[ -n "${TELEGRAM_MESSAGE_THREAD_ID:-}" ]]; then
  CURL_ARGS+=(-d "message_thread_id=${TELEGRAM_MESSAGE_THREAD_ID}")
fi

curl "${CURL_ARGS[@]}" >/dev/null || true
