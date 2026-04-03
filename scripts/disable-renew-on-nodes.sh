#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source /opt/ssl-renewal/lib.sh
load_config

[[ "${ROLE}" == "main" ]] || { echo "disable-renew-on-nodes.sh runs only on main." >&2; exit 1; }

[[ -f "${NODES_FILE}" ]] || { echo "Nodes file not found: ${NODES_FILE}" >&2; exit 1; }

while IFS= read -r NODE || [[ -n "$NODE" ]]; do
  [[ -z "$NODE" ]] && continue
  [[ "$NODE" =~ ^[[:space:]]*# ]] && continue
  echo "==> ${NODE}"
  ssh -n "$NODE" "
    mkdir -p /etc/ssl-renewal /opt/ssl-renewal/logs &&
    test -f /etc/ssl-renewal/config.env || cat > /etc/ssl-renewal/config.env <<'EOF'
ROLE=\"node\"
APP_DIR=\"/opt/ssl-renewal\"
ETC_DIR=\"/etc/ssl-renewal\"
PRIMARY_DOMAIN=\"${PRIMARY_DOMAIN}\"
TARGET_DIR=\"${TARGET_DIR}\"
CERT_DIR=\"${TARGET_DIR}\"
LOG_DIR=\"/opt/ssl-renewal/logs\"
TELEGRAM_ENABLED=\"0\"
DEVELOPER_NAME=\"Indie_Master\"
DEVELOPER_GITHUB=\"https://github.com/indie-master\"
EOF
    systemctl disable --now certbot.timer 2>/dev/null || true
    systemctl disable --now snap.certbot.renew.timer 2>/dev/null || true
    systemctl mask certbot.service certbot.timer 2>/dev/null || true
    systemctl mask snap.certbot.renew.service snap.certbot.renew.timer 2>/dev/null || true
    mkdir -p /root/letsencrypt-hooks-backup
    find /etc/letsencrypt/renewal-hooks -type f -exec mv -t /root/letsencrypt-hooks-backup/ {} + 2>/dev/null || true
    rm -f '/etc/letsencrypt/renewal/${PRIMARY_DOMAIN}.conf' 2>/dev/null || true
    rm -rf '/etc/letsencrypt/archive/${PRIMARY_DOMAIN}' 2>/dev/null || true
  " < /dev/null
done < "${NODES_FILE}"
