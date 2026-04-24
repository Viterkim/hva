#!/usr/bin/env bash
# Validation helpers. Source this, call env_validate_required.

env_apply_defaults() {
  export HVA_LSP_ENABLED="${HVA_LSP_ENABLED:-rust,typescript,python,json,html,css,yaml,bash,docker,go,clangd}"
  export HVA_LSP_DISABLED="${HVA_LSP_DISABLED:-csharp}"
  if [[ -z "${HVA_MANAGE_AGENTS+x}" && -n "${HVA_COPY_AGENTS+x}" ]]; then
    export HVA_MANAGE_AGENTS="$HVA_COPY_AGENTS"
  fi
  export HVA_MANAGE_AGENTS="${HVA_MANAGE_AGENTS:-1}"
  export HVA_COPY_AGENTS="${HVA_COPY_AGENTS:-$HVA_MANAGE_AGENTS}"
  export HVA_LOAD_MCP_ENV="${HVA_LOAD_MCP_ENV:-1}"
  export HVA_MOUNT_GITCONFIG="${HVA_MOUNT_GITCONFIG:-0}"
  export HVA_MOUNT_NVIM="${HVA_MOUNT_NVIM:-0}"
  export HVA_MOUNT_SSH="${HVA_MOUNT_SSH:-0}"
  export HVA_LOG_NANOCODER_OUTPUT="${HVA_LOG_NANOCODER_OUTPUT:-0}"
  export HVA_LOG_TOOL_OUTPUT="${HVA_LOG_TOOL_OUTPUT:-0}"
  export HVA_UNSAFE="${HVA_UNSAFE:-0}"

  export LLAMA_AUTOFIT_TOKENS="${LLAMA_AUTOFIT_TOKENS:-1024}"
  export LLAMA_ENABLE_THINKING="${LLAMA_ENABLE_THINKING:-1}"
  export LLAMA_PRESERVE_THINKING="${LLAMA_PRESERVE_THINKING:-1}"
  export LLAMA_TEMPERATURE="${LLAMA_TEMPERATURE:-0.6}"
  export LLAMA_TOP_P="${LLAMA_TOP_P:-0.95}"
  export LLAMA_TOP_K="${LLAMA_TOP_K:-20}"
  export LLAMA_MIN_P="${LLAMA_MIN_P:-0.0}"
  export LLAMA_PRESENCE_PENALTY="${LLAMA_PRESENCE_PENALTY:-0.0}"
  export LLAMA_REPEAT_PENALTY="${LLAMA_REPEAT_PENALTY:-1.0}"
}

env_is_number() {
  [[ "${1:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

env_validate_common() {
  local missing=0

  env_apply_defaults

  if [[ -z "${LLAMA_MODELS:-}" ]]; then
    echo "LLAMA_MODELS is not set" >&2
    missing=1
  fi

  if [[ -z "${LLAMA_MODEL_ALIAS:-}" ]]; then
    echo "LLAMA_MODEL_ALIAS is not set" >&2
    missing=1
  fi

  if [[ -z "${LLAMA_CONTAINER:-}" ]]; then
    echo "LLAMA_CONTAINER is not set" >&2
    missing=1
  fi

  if [[ -z "${LLAMA_HOST_PORT:-}" ]]; then
    echo "LLAMA_HOST_PORT is not set" >&2
    missing=1
  fi

  if [[ -z "${LLAMA_CONTEXT_SIZE:-}" ]]; then
    echo "LLAMA_CONTEXT_SIZE is not set" >&2
    missing=1
  fi

  if [[ -z "${LLAMA_REASONING_BUDGET:-}" ]]; then
    echo "LLAMA_REASONING_BUDGET is not set" >&2
    missing=1
  fi

  if [[ -z "${LLAMA_NCMOE:-}" ]]; then
    echo "LLAMA_NCMOE is not set" >&2
    missing=1
  fi

  if [[ -z "${LLAMA_AUTOFIT_TOKENS+x}" ]]; then
    echo "LLAMA_AUTOFIT_TOKENS is not set" >&2
    missing=1
  fi

  if [[ -z "${HVA_MCP_ENABLED:-}" ]]; then
    echo "HVA_MCP_ENABLED is not set" >&2
    missing=1
  fi

  if [[ -z "${HVA_MCP_DISABLED:-}" ]]; then
    echo "HVA_MCP_DISABLED is not set" >&2
    missing=1
  fi

  for var in HVA_MANAGE_AGENTS HVA_LOAD_MCP_ENV HVA_MOUNT_GITCONFIG HVA_MOUNT_NVIM HVA_MOUNT_SSH HVA_LOG_NANOCODER_OUTPUT HVA_LOG_TOOL_OUTPUT HVA_UNSAFE; do
    if [[ -z "${!var+x}" ]]; then
      echo "$var is not set" >&2
      missing=1
    fi
  done

  if (( missing == 1 )); then
    echo "Copy env/env-source-sample.sh to env/env-source.sh and fill in values." >&2
    exit 1
  fi

  for var in HVA_MANAGE_AGENTS HVA_LOAD_MCP_ENV HVA_MOUNT_GITCONFIG HVA_MOUNT_NVIM HVA_MOUNT_SSH HVA_LOG_NANOCODER_OUTPUT HVA_LOG_TOOL_OUTPUT HVA_UNSAFE LLAMA_ENABLE_THINKING LLAMA_PRESERVE_THINKING; do
    case "${!var}" in
      0|1) ;;
      *) echo "$var must be 0 or 1: ${!var}" >&2; exit 1 ;;
    esac
  done

  case "${LLAMA_HOST_PORT:-}" in
    ''|*[!0-9]*)
      echo "LLAMA_HOST_PORT must be a number: ${LLAMA_HOST_PORT:-<unset>}" >&2
      exit 1
      ;;
  esac

  case "${LLAMA_CONTEXT_SIZE:-}" in
    ''|*[!0-9]*)
      echo "LLAMA_CONTEXT_SIZE must be a number: ${LLAMA_CONTEXT_SIZE:-<unset>}" >&2
      exit 1
      ;;
  esac

  case "${LLAMA_REASONING_BUDGET:-}" in
    -1)
      ;;
    ''|*[!0-9]*)
      echo "LLAMA_REASONING_BUDGET must be -1 or a non-negative number: ${LLAMA_REASONING_BUDGET:-<unset>}" >&2
      exit 1
      ;;
    *)
      ;;
  esac

  case "${LLAMA_NCMOE:-}" in
    ''|*[!0-9]*)
      echo "LLAMA_NCMOE must be a number: ${LLAMA_NCMOE:-<unset>}" >&2
      exit 1
      ;;
  esac

  case "${LLAMA_AUTOFIT_TOKENS:-}" in
    ''|0)
      ;;
    *[!0-9]*)
      echo "LLAMA_AUTOFIT_TOKENS must be empty, 0, or a number: ${LLAMA_AUTOFIT_TOKENS}" >&2
      exit 1
      ;;
  esac

  case "${LLAMA_TOP_K:-}" in
    ''|*[!0-9]*)
      echo "LLAMA_TOP_K must be a number: ${LLAMA_TOP_K:-<unset>}" >&2
      exit 1
      ;;
  esac

  for var in LLAMA_TEMPERATURE LLAMA_TOP_P LLAMA_MIN_P LLAMA_PRESENCE_PENALTY LLAMA_REPEAT_PENALTY; do
    if ! env_is_number "${!var}"; then
      echo "$var must be a non-negative number: ${!var}" >&2
      exit 1
    fi
  done

  if [[ ! -d "$LLAMA_MODELS" ]]; then
    echo "LLAMA_MODELS directory does not exist: $LLAMA_MODELS" >&2
    exit 1
  fi

  env_validate_mcp_lists
  env_validate_lsp_lists
}

env_validate_model() {
  if [[ -z "${LLAMA_MODEL:-}" ]]; then
    local model_count=0
    local model_path=""

    while IFS= read -r -d '' candidate; do
      model_count=$((model_count + 1))
      model_path="$candidate"
    done < <(find "$LLAMA_MODELS" -maxdepth 1 -type f -name '*.gguf' -print0)

    if (( model_count == 1 )); then
      LLAMA_MODEL="$(basename "$model_path")"
      export LLAMA_MODEL
    elif (( model_count == 0 )); then
      echo "LLAMA_MODEL is empty and no .gguf files were found in LLAMA_MODELS: $LLAMA_MODELS" >&2
      exit 1
    else
      echo "LLAMA_MODEL is empty but multiple .gguf files exist in LLAMA_MODELS: $LLAMA_MODELS" >&2
      echo "Set LLAMA_MODEL explicitly in env/env-source.sh." >&2
      exit 1
    fi
  fi

  if [[ ! -f "$LLAMA_MODELS/$LLAMA_MODEL" ]]; then
    echo "Model file does not exist: $LLAMA_MODELS/$LLAMA_MODEL" >&2
    exit 1
  fi
}

env_validate_mcp_lists() {
  local hva_root
  hva_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
  local mcp_json="$hva_root/nanocoder/.mcp.json"

  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for MCP validation" >&2
    exit 1
  fi
  if [[ ! -f "$mcp_json" ]]; then
    echo "MCP catalog not found: $mcp_json" >&2
    exit 1
  fi

  local known_mcp
  known_mcp="$(jq -r '.mcpServers | keys | join(" ")' "$mcp_json")"

  local combined_mcp=",$HVA_MCP_ENABLED,$HVA_MCP_DISABLED,"
  local seen_mcp=","
  local mcp_name
  IFS=',' read -r -a mcp_values <<< "$HVA_MCP_ENABLED,$HVA_MCP_DISABLED"
  for mcp_name in "${mcp_values[@]}"; do
    [[ -z "$mcp_name" ]] && continue
    if [[ " $known_mcp " != *" $mcp_name "* ]]; then
      echo "unknown MCP server in env/env-source.sh: $mcp_name" >&2
      echo "known MCP servers: $known_mcp" >&2
      exit 1
    fi
    if [[ "$seen_mcp" == *",$mcp_name,"* ]]; then
      echo "MCP server listed more than once or in both enabled/disabled: $mcp_name" >&2
      exit 1
    fi
    seen_mcp+="$mcp_name,"
  done

  for mcp_name in $known_mcp; do
    if [[ "$combined_mcp" != *",$mcp_name,"* ]]; then
      echo "MCP server is not listed in enabled or disabled: $mcp_name" >&2
      echo "Add it to HVA_MCP_ENABLED or HVA_MCP_DISABLED in env/env-source.sh." >&2
      exit 1
    fi
  done
}

env_validate_lsp_lists() {
  env_apply_defaults
  local known_lsp="rust typescript python json html css yaml bash docker go clangd csharp"
  local combined_lsp=",$HVA_LSP_ENABLED,$HVA_LSP_DISABLED,"
  local seen_lsp=","
  local lsp_name
  IFS=',' read -r -a lsp_values <<< "$HVA_LSP_ENABLED,$HVA_LSP_DISABLED"
  for lsp_name in "${lsp_values[@]}"; do
    [[ -z "$lsp_name" ]] && continue
    if [[ " $known_lsp " != *" $lsp_name "* ]]; then
      echo "unknown LSP in env/env-source.sh: $lsp_name" >&2
      echo "known LSPs: $known_lsp" >&2
      exit 1
    fi
    if [[ "$seen_lsp" == *",$lsp_name,"* ]]; then
      echo "LSP listed more than once or in both enabled/disabled: $lsp_name" >&2
      exit 1
    fi
    seen_lsp+="$lsp_name,"
  done

  for lsp_name in $known_lsp; do
    if [[ "$combined_lsp" != *",$lsp_name,"* ]]; then
      echo "LSP is not listed in enabled or disabled: $lsp_name" >&2
      echo "Add it to HVA_LSP_ENABLED or HVA_LSP_DISABLED in env/env-source.sh." >&2
      exit 1
    fi
  done
}

env_validate_required() {
  env_validate_common
  env_validate_model
}
