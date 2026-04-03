#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/ssl-renewal/config.env"
[[ -f "$CONFIG" ]] || { echo "Missing config: $CONFIG" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"

mkdir -p "${TARGET_DIR}"
chmod 755 /etc/letsencrypt || true
chmod 755 /etc/letsencrypt/live || true
chmod 755 "${TARGET_DIR}" || true

disable_renew() {
  systemctl disable --now certbot.timer 2>/dev/null || true
  systemctl disable --now snap.certbot.renew.timer 2>/dev/null || true
  systemctl mask certbot.service certbot.timer 2>/dev/null || true
  systemctl mask snap.certbot.renew.service snap.certbot.renew.timer 2>/dev/null || true

  mkdir -p /root/letsencrypt-hooks-backup
  find /etc/letsencrypt/renewal-hooks -type f -exec mv -t /root/letsencrypt-hooks-backup/ {} + 2>/dev/null || true
  rm -f "/etc/letsencrypt/renewal/${PRIMARY_DOMAIN}.conf" 2>/dev/null || true
  rm -rf "/etc/letsencrypt/archive/${PRIMARY_DOMAIN}" 2>/dev/null || true
}

if [[ "${1:-}" == "--disable-renew-only" ]]; then
  disable_renew
  exit 0
fi

disable_renew
echo "Node prepared. Directory: ${TARGET_DIR}"
