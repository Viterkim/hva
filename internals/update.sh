#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
HVA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

STATE_ROOT="$HVA_ROOT/.hva-state"
PI_CONFIG_ROOT="$STATE_ROOT/pi-agent"

echo "=== hva update ==="
echo ""

# pull latest
cd "$HVA_ROOT"
echo "pulling latest changes..."
git pull --ff-only
echo ""

echo "ensuring config/hva-conf.json exists..."
"$HVA_ROOT/internals/sync-config.sh"
echo ""

if [[ -d "$PI_CONFIG_ROOT" ]]; then
  echo "pi config exists — generated files will refresh on next: hva"
else
  echo "pi config will be created fresh on next: hva"
fi
echo ""

echo "update complete. if the dev image changed, it will rebuild automatically on next: hva"
