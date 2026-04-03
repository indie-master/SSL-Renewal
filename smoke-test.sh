#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "Running bash syntax checks..."
for f in install.sh scripts/*.sh scripts/ssl-renewal; do
  echo "  bash -n $f"
  bash -n "$f"
done
echo "Syntax checks passed."
