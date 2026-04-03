#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source /opt/ssl-renewal/lib.sh
load_config

[[ "${ROLE}" == "main" ]] || { echo "deploy-certs.sh запускается только на main." >&2; exit 1; }

mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/deploy-certs.log"
OK_NODES=()
FAIL_NODES=()

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

notify() {
  notify_tg "$1"
}

[[ -f "${CERT_DIR}/fullchain.pem" && -f "${CERT_DIR}/privkey.pem" ]] || { log "Certificate files not found in ${CERT_DIR}"; exit 1; }
[[ -f "${NODES_FILE}" ]] || { log "Nodes file not found: ${NODES_FILE}"; exit 1; }

log "=== DEPLOY START on $(hostname -f 2>/dev/null || hostname) ==="

while IFS= read -r NODE || [[ -n "$NODE" ]]; do
  [[ -z "$NODE" ]] && continue
  [[ "$NODE" =~ ^[[:space:]]*# ]] && continue

  log "==> ${NODE}"

  if ! ssh -n "$NODE" "mkdir -p '${TARGET_DIR}' && chmod 755 /etc/letsencrypt /etc/letsencrypt/live '${TARGET_DIR}'" < /dev/null; then
    log "ERROR: mkdir/chmod failed on ${NODE}"
    FAIL_NODES+=("$NODE")
    continue
  fi

  if ! scp -q "${CERT_DIR}/fullchain.pem" "${NODE}:${TARGET_DIR}/fullchain.pem.new" < /dev/null; then
    log "ERROR: fullchain copy failed on ${NODE}"
    FAIL_NODES+=("$NODE")
    continue
  fi

  if ! scp -q "${CERT_DIR}/privkey.pem" "${NODE}:${TARGET_DIR}/privkey.pem.new" < /dev/null; then
    log "ERROR: privkey copy failed on ${NODE}"
    FAIL_NODES+=("$NODE")
    continue
  fi

  if ! ssh -n "$NODE" "
    chmod 644 '${TARGET_DIR}/fullchain.pem.new' &&
    chmod 600 '${TARGET_DIR}/privkey.pem.new' &&
    mv '${TARGET_DIR}/fullchain.pem.new' '${TARGET_DIR}/fullchain.pem' &&
    mv '${TARGET_DIR}/privkey.pem.new' '${TARGET_DIR}/privkey.pem' &&
    nginx -t &&
    systemctl reload nginx
  " < /dev/null; then
    log "ERROR: activate/reload failed on ${NODE}"
    FAIL_NODES+=("$NODE")
    continue
  fi

  log "OK: ${NODE}"
  OK_NODES+=("$NODE")
done < "${NODES_FILE}"

log "--- SUMMARY ---"
log "OK nodes: ${#OK_NODES[@]}"
for n in "${OK_NODES[@]}"; do log "  OK   $n"; done
log "FAIL nodes: ${#FAIL_NODES[@]}"
for n in "${FAIL_NODES[@]}"; do log "  FAIL $n"; done

if [[ -f "${APP_DIR}/.disable_nodes_after_first_deploy" ]]; then
  /opt/ssl-renewal/disable-renew-on-nodes.sh || true
  rm -f "${APP_DIR}/.disable_nodes_after_first_deploy"
fi

if [[ ${#FAIL_NODES[@]} -gt 0 ]]; then
  notify "⚠️ <b>SSL Renewal deploy finished with errors</b>%0AHost: <code>$(hostname -f 2>/dev/null || hostname)</code>%0AOK: ${#OK_NODES[@]}%0AFAIL: ${#FAIL_NODES[@]}"
  exit 1
fi

notify "✅ <b>SSL Renewal deploy successful</b>%0AHost: <code>$(hostname -f 2>/dev/null || hostname)</code>%0ANodes updated: ${#OK_NODES[@]}"
log "=== DEPLOY END ==="
