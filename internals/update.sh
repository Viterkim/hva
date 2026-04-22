#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
HVA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

STATE_ROOT="$HVA_ROOT/.hva-state"
NANOCODER_CONFIG_ROOT="$STATE_ROOT/nanocoder-configs"

echo "=== hva update ==="
echo ""

# pull latest
cd "$HVA_ROOT"
echo "pulling latest changes..."
git pull --ff-only
echo ""

# clear nanocoder config cache so stale preferences/mcp get rebuilt on next run
if [[ -d "$NANOCODER_CONFIG_ROOT" ]]; then
  echo "clearing nanocoder config cache..."
  rm -rf "$NANOCODER_CONFIG_ROOT"
  echo "done — fresh config will be written on next: hva"
else
  echo "nanocoder config cache already clean"
fi
echo ""

echo "update complete. if the dev image changed, it will rebuild automatically on next: hva"
