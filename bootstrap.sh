#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <git_repo_url> [main|node]" >&2
  exit 1
fi

REPO_URL="$1"
ROLE="${2:-main}"

case "$ROLE" in
  main|node) ;;
  *)
    echo "Error: role must be 'main' or 'node'." >&2
    echo "Usage: $0 <git_repo_url> [main|node]" >&2
    exit 1
    ;;
esac

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi

  echo "git not found. Attempting to install git..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y git
  else
    echo "Error: git is required but could not be auto-installed on this system." >&2
    exit 1
  fi

  command -v git >/dev/null 2>&1 || {
    echo "Error: git installation failed." >&2
    exit 1
  }
}

ensure_git

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"
git clone "$REPO_URL" repo
cd repo
chmod +x install.sh
sudo ./install.sh "$ROLE"

cat <<EOF2

Installation command completed.
Recommended next commands:
  ssl-renewal help
  ssl-renewal doctor
  ssl-renewal cloudflare-help
  ssl-renewal status

EOF2
