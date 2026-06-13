#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: bootstrap.sh <git_repo_url> <main|node>

Examples:
  bootstrap.sh https://github.com/indie-master/SSL-Renewal.git main
  bootstrap.sh https://github.com/indie-master/SSL-Renewal.git node
USAGE
}

run_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
  else
    command -v sudo >/dev/null 2>&1 || { echo "Error: sudo is required when not running as root." >&2; exit 1; }
    sudo "$@"
  fi
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    echo "git not found; installing git with apt-get..."
    run_root env DEBIAN_FRONTEND=noninteractive apt-get update -y
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y git ca-certificates
  else
    echo "Error: git is required, and automatic installation is only supported on apt-based systems." >&2
    exit 1
  fi

  command -v git >/dev/null 2>&1 || { echo "Error: git installation failed or git is still unavailable." >&2; exit 1; }
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

REPO_URL="$1"
ROLE="$2"

case "$REPO_URL" in
  https://github.com/*/*.git|https://github.com/*/*)
    ;;
  *)
    echo "Error: repo_url must be an https://github.com/<owner>/<repo>[.git] URL." >&2
    usage
    exit 1
    ;;
esac

case "$ROLE" in
  main|node) ;;
  *)
    echo "Error: role must be 'main' or 'node'." >&2
    usage
    exit 1
    ;;
esac

ensure_git

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

printf 'Cloning SSL Renewal from %s...\n' "$REPO_URL"
git clone --depth 1 "$REPO_URL" "$TMP_DIR/repo"
cd "$TMP_DIR/repo"
chmod +x install.sh

printf 'Running SSL Renewal installer for role: %s\n' "$ROLE"
run_root ./install.sh "$ROLE"

cat <<EOF2

SSL Renewal bootstrap finished for role: ${ROLE}

Next steps:
  1. Review installer output above for any deferred manual steps.
  Main server:
    ssl-renewal paths
    ssl-renewal edit-config
    ssl-renewal doctor
    ssl-renewal issue
    ssl-renewal deploy
    ssl-renewal dry-run

  Node server:
    ensure nginx uses /etc/letsencrypt/live/<PRIMARY_DOMAIN>/fullchain.pem
    and /etc/letsencrypt/live/<PRIMARY_DOMAIN>/privkey.pem, then run:
    nginx -t && systemctl reload nginx

Security note:
  Review bootstrap.sh before running remote shell commands:
  https://github.com/indie-master/SSL-Renewal/blob/main/bootstrap.sh
EOF2
