#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/ssl-renewal/config.env"
# shellcheck disable=SC1090
source "$CONFIG"

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

NEW_CERT="ssl_certificate     ${TARGET_DIR}/fullchain.pem;"
NEW_KEY="ssl_certificate_key ${TARGET_DIR}/privkey.pem;"
BACKUP_DIR="/root/nginx-ssl-renewal-backup-$(date +%F-%H%M%S)"
mkdir -p "$BACKUP_DIR"

mapfile -t files < <(grep -RIl --include='*.conf' -E '^[[:space:]]*ssl_certificate[[:space:]]+|^[[:space:]]*ssl_certificate_key[[:space:]]+' /etc/nginx 2>/dev/null || true)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "Nginx conf files with ssl_certificate directives not found."
  exit 0
fi

echo "Будут затронуты файлы:"
printf '  %s
' "${files[@]}"

if [[ "$APPLY" -eq 0 ]]; then
  cat <<EOF

Preview mode.
Новый путь:
  ${NEW_CERT}
  ${NEW_KEY}

Применить:
  ssl-renewal patch-nginx --apply
EOF
  exit 0
fi

for f in "${files[@]}"; do
  cp -a "$f" "$BACKUP_DIR/"
  sed -i -E "s|^[[:space:]]*ssl_certificate[[:space:]]+[^;]+;|    ${NEW_CERT}|g" "$f"
  sed -i -E "s|^[[:space:]]*ssl_certificate_key[[:space:]]+[^;]+;|    ${NEW_KEY}|g" "$f"
done

if nginx -t; then
  systemctl reload nginx
  echo "Nginx paths updated successfully. Backup: $BACKUP_DIR"
else
  echo "nginx -t failed, rolling back..." >&2
  for f in "${files[@]}"; do
    cp -a "$BACKUP_DIR/$(basename "$f")" "$f"
  done
  nginx -t || true
  exit 1
fi
