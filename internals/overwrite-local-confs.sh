#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd -P)"
NANOCODER_DIR="${NANOCODER_CONFIG_DIR:-$HOME/.config/nanocoder}"

mkdir -p "$NANOCODER_DIR/bin"

cp -n "$ROOT/nanocoder/nanocoder-preferences.sample.json" "$ROOT/nanocoder/nanocoder-preferences.json"
"$ROOT/nanocoder/render-agents-config.sh" "$ROOT/nanocoder/agents.config.json"
"$ROOT/nanocoder/render-mcp-config.sh" "$NANOCODER_DIR/.mcp.json"
"$ROOT/nanocoder/render-lsp-mask.sh" "$NANOCODER_DIR/bin/lsp-mask"

ln -sfn "$ROOT/nanocoder/.gitignore" "$NANOCODER_DIR/.gitignore"
ln -sfn "$ROOT/nanocoder/agents.config.json" "$NANOCODER_DIR/agents.config.json"
ln -sfn "$ROOT/nanocoder/nanocoder-preferences.json" "$NANOCODER_DIR/nanocoder-preferences.json"

for helper in "$ROOT"/nanocoder/bin/*; do
  helper_name="$(basename "$helper")"
  ln -sfn "$helper" "$NANOCODER_DIR/bin/$helper_name"
done

printf 'nanocoder config synced: %s\n' "$NANOCODER_DIR"
