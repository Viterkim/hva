#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd -P)"
PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

# shellcheck disable=SC1091
source "$ROOT/internals/load-config.sh"
env_validate_required

"$ROOT/internals/install-pi-extension-deps.sh"

mkdir -p "$PI_DIR"

"$ROOT/pi/render-settings.sh" "$PI_DIR/settings.json" >/dev/null
"$ROOT/pi/render-models.sh" "$PI_DIR/models.json" "http://127.0.0.1:${LLAMA_HOST_PORT:-8080}/v1" >/dev/null

printf 'pi config synced: %s\n' "$PI_DIR"
