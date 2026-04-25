#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
OUTPUT="${1:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/models.json}"
BASE_URL="${2:-http://127.0.0.1:8080/v1}"
OUTPUT_DIR="$(dirname "$OUTPUT")"

# shellcheck disable=SC1091
source "$ROOT/internals/load-config.sh"
env_validate_required

reasoning=false
if [[ "${LLAMA_ENABLE_THINKING:-0}" == "1" ]]; then
  reasoning=true
fi

max_tokens="16384"
if [[ -n "${LLAMA_AUTOFIT_TOKENS:-}" && "${LLAMA_AUTOFIT_TOKENS:-}" != "0" ]]; then
  max_tokens="$LLAMA_AUTOFIT_TOKENS"
fi

mkdir -p "$OUTPUT_DIR"
tmp_output="$(mktemp "$OUTPUT_DIR/models.json.XXXXXX")"

jq -n \
  --arg base_url "$BASE_URL" \
  --arg model_id "$LLAMA_MODEL_ALIAS" \
  --arg model_name "$LLAMA_MODEL_ALIAS" \
  --argjson context_window "$LLAMA_CONTEXT_SIZE" \
  --argjson max_tokens "$max_tokens" \
  --argjson reasoning "$reasoning" \
  '{
    providers: {
      local: {
        baseUrl: $base_url,
        api: "openai-completions",
        apiKey: "local",
        compat: {
          supportsDeveloperRole: false,
          supportsReasoningEffort: false,
          supportsUsageInStreaming: false,
          maxTokensField: "max_tokens",
          thinkingFormat: "qwen-chat-template"
        },
        models: [
          {
            id: $model_id,
            name: $model_name,
            reasoning: $reasoning,
            input: ["text"],
            contextWindow: $context_window,
            maxTokens: $max_tokens,
            cost: {
              input: 0,
              output: 0,
              cacheRead: 0,
              cacheWrite: 0
            }
          }
        ]
      }
    }
  }' > "$tmp_output"

mv "$tmp_output" "$OUTPUT"
printf '%s\n' "$OUTPUT"
