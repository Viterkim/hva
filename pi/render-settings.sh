#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
OUTPUT="${1:-$HOME/.pi/agent/settings.json}"
OUTPUT_DIR="$(dirname "$OUTPUT")"

# shellcheck disable=SC1091
source "$ROOT/internals/load-config.sh"
env_validate_required

thinking_level="off"
if [[ "${LLAMA_ENABLE_THINKING:-0}" == "1" ]]; then
  thinking_level="medium"
fi

mkdir -p "$OUTPUT_DIR"
tmp_output="$(mktemp "$OUTPUT_DIR/settings.json.XXXXXX")"

jq -n \
  --arg default_provider "local" \
  --arg default_model "$LLAMA_MODEL_ALIAS" \
  --arg default_thinking_level "$thinking_level" \
  '{
    defaultProvider: $default_provider,
    defaultModel: $default_model,
    defaultThinkingLevel: $default_thinking_level,
    compaction: {
      enabled: false,
      reserveTokens: 1024,
      keepRecentTokens: 999999999
    },
    branchSummary: {
      skipPrompt: true,
      reserveTokens: 1024
    },
    hideThinkingBlock: false,
    images: {
      autoResize: true,
      blockImages: false
    },
    enableInstallTelemetry: false,
    quietStartup: true,
    theme: "dark"
  }' > "$tmp_output"

mv "$tmp_output" "$OUTPUT"
printf '%s\n' "$OUTPUT"
