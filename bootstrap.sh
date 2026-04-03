#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <git_repo_url> [main|node]" >&2
  exit 1
fi

REPO_URL="$1"
ROLE="${2:-main}"

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but not installed." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"
git clone "$REPO_URL" repo
cd repo
chmod +x install.sh
sudo ./install.sh "$ROLE"
