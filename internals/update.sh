#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
HVA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

STATE_ROOT="$HVA_ROOT/.hva-state"
PI_CONFIG_ROOT="$STATE_ROOT/pi-home/agent"

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

echo "checking for sample value differences..."
changed_keys="$(jq -rn \
  --slurpfile sample "$HVA_ROOT/config/hva-conf.json.sample" \
  --slurpfile user   "$HVA_ROOT/config/hva-conf.json" '
    $sample[0] as $s | $user[0] as $u
    | ($s | keys_unsorted[]) as $k
    | select(($u | has($k)) and ($s[$k] != $u[$k]))
    | "\($k)\t\($s[$k])\t\($u[$k])"
  ' || true)"
if [[ -n "$changed_keys" ]]; then
  echo "  your config differs from the current sample defaults:"
  echo ""
  while IFS=$'\t' read -r key sample_val user_val; do
    printf '  %-36s  sample: %-20s  yours: %s\n' "$key" "$sample_val" "$user_val"
  done <<< "$changed_keys"
  echo ""
  echo "  these are informational — your config is valid as-is. update manually if you want."
else
  echo "  no differences from sample defaults."
fi
echo ""

if [[ -d "$PI_CONFIG_ROOT" ]]; then
  echo "pi config exists — generated files will refresh on next: hva"
else
  echo "pi config will be created fresh on next: hva"
fi
echo ""

echo "update complete. if the dev image changed, it will rebuild automatically on next: hva"
