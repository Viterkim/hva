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

echo "syncing env/env-source.sh with new sample vars..."
"$HVA_ROOT/internals/sync-env-source.sh"
echo ""

if [[ -d "$NANOCODER_CONFIG_ROOT" ]]; then
  echo "nanocoder config cache is versioned now — stale config will auto-refresh on next: hva"
else
  echo "nanocoder config cache will be created fresh on next: hva"
fi
echo ""

echo "update complete. if the dev image changed, it will rebuild automatically on next: hva"
