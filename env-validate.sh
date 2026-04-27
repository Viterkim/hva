#!/usr/bin/env bash
# Validation helpers. Source this, call env_validate_required.

ENV_CONFIG_KEYS=(
  LLAMA_MODELS
  LLAMA_MODEL_ALIAS
  LLAMA_CONTAINER
  LLAMA_HOST_PORT
  LLAMA_NETWORK
  LLAMA_CONTEXT_SIZE
  LLAMA_REASONING_BUDGET
  LLAMA_NCMOE
  LLAMA_AUTOFIT_TOKENS
  LLAMA_ENABLE_THINKING
  LLAMA_PRESERVE_THINKING
  LLAMA_TEMPERATURE
  LLAMA_TOP_P
  LLAMA_TOP_K
  LLAMA_MIN_P
  LLAMA_PRESENCE_PENALTY
  LLAMA_REPEAT_PENALTY
  HVA_MCP_ENABLED
  HVA_MCP_DISABLED
  SEARXNG_URL
  HVA_LOAD_SECRETS
  HVA_MOUNT_GIT
  HVA_MOUNT_GITCONFIG
  HVA_MOUNT_NVIM
  HVA_MOUNT_SSH
  HVA_MOUNT_DOCKER_SOCKET
  HVA_UNSAFE
  HVA_CSHARP
  LLAMA_GPU_VENDOR
  LLAMA_MODEL
  LLAMA_IMAGE
)

ENV_REQUIRED_NONEMPTY_KEYS=(
  LLAMA_MODELS
  LLAMA_MODEL_ALIAS
  LLAMA_CONTAINER
  LLAMA_HOST_PORT
  LLAMA_NETWORK
  LLAMA_CONTEXT_SIZE
  LLAMA_REASONING_BUDGET
  LLAMA_NCMOE
  HVA_LOAD_SECRETS
  HVA_MOUNT_GIT
  HVA_MOUNT_GITCONFIG
  HVA_MOUNT_NVIM
  HVA_MOUNT_SSH
  HVA_MOUNT_DOCKER_SOCKET
)

ENV_BOOLEAN_01_KEYS=(
  HVA_LOAD_SECRETS
  HVA_MOUNT_GIT
  HVA_MOUNT_GITCONFIG
  HVA_MOUNT_NVIM
  HVA_MOUNT_SSH
  HVA_MOUNT_DOCKER_SOCKET
  HVA_UNSAFE
  LLAMA_ENABLE_THINKING
  LLAMA_PRESERVE_THINKING
)

ENV_UNSIGNED_INT_KEYS=(
  LLAMA_HOST_PORT
  LLAMA_CONTEXT_SIZE
  LLAMA_NCMOE
  LLAMA_TOP_K
)

ENV_NONNEG_NUMBER_KEYS=(
  LLAMA_TEMPERATURE
  LLAMA_TOP_P
  LLAMA_MIN_P
  LLAMA_PRESENCE_PENALTY
  LLAMA_REPEAT_PENALTY
)

KNOWN_MCP_KEYS=(
  github
  ripgrep
  rust-docs
  pypi
  npm-search
  brave-search
  searxng
)

env_is_number() {
  [[ "${1:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

env_require_present() {
  local var
  local missing=0

  for var in "$@"; do
    if [[ -z "${!var+x}" ]]; then
      echo "$var is missing from config" >&2
      missing=1
    fi
  done

  return "$missing"
}

env_require_nonempty() {
  local var
  local missing=0

  for var in "$@"; do
    if [[ -n "${!var+x}" && -z "${!var:-}" ]]; then
      echo "$var is not set" >&2
      missing=1
    fi
  done

  return "$missing"
}

env_require_boolean_01() {
  local var

  for var in "$@"; do
    case "${!var}" in
      0|1) ;;
      *) echo "$var must be 0 or 1: ${!var}" >&2; exit 1 ;;
    esac
  done
}

env_require_unsigned_int() {
  local var

  for var in "$@"; do
    case "${!var:-}" in
      ''|*[!0-9]*)
        echo "$var must be a number: ${!var:-<unset>}" >&2
        exit 1
        ;;
    esac
  done
}

env_require_non_negative_number() {
  local var

  for var in "$@"; do
    if ! env_is_number "${!var}"; then
      echo "$var must be a non-negative number: ${!var}" >&2
      exit 1
    fi
  done
}

env_validate_common() {
  local missing=0
  local mcp_name
  local combined_mcp seen_mcp

  env_require_present "${ENV_CONFIG_KEYS[@]}" || missing=1
  env_require_nonempty "${ENV_REQUIRED_NONEMPTY_KEYS[@]}" || missing=1

  if (( missing == 1 )); then
    echo "Create config/hva-conf.json from config/hva-conf.json.sample." >&2
    exit 1
  fi

  env_require_boolean_01 "${ENV_BOOLEAN_01_KEYS[@]}"

  case "${HVA_CSHARP:-}" in
    true|false) ;;
    *) echo "HVA_CSHARP must be true or false: ${HVA_CSHARP:-<unset>}" >&2; exit 1 ;;
  esac

  case "${LLAMA_GPU_VENDOR:-}" in
    auto|nvidia|amd|intel|none|cpu) ;;
    *) echo "LLAMA_GPU_VENDOR must be auto, nvidia, amd, intel, none, or cpu: ${LLAMA_GPU_VENDOR:-<unset>}" >&2; exit 1 ;;
  esac

  env_require_unsigned_int "${ENV_UNSIGNED_INT_KEYS[@]}"
  env_require_non_negative_number "${ENV_NONNEG_NUMBER_KEYS[@]}"

  case "${LLAMA_REASONING_BUDGET:-}" in
    -1) ;;
    ''|*[!0-9]*)
      echo "LLAMA_REASONING_BUDGET must be -1 or a non-negative number: ${LLAMA_REASONING_BUDGET:-<unset>}" >&2
      exit 1
      ;;
  esac

  case "${LLAMA_AUTOFIT_TOKENS:-}" in
    ''|0) ;;
    *[!0-9]*)
      echo "LLAMA_AUTOFIT_TOKENS must be empty, 0, or a number: ${LLAMA_AUTOFIT_TOKENS}" >&2
      exit 1
      ;;
  esac

  if [[ ! -d "${LLAMA_MODELS:-}" ]]; then
    echo "LLAMA_MODELS directory does not exist: ${LLAMA_MODELS:-<unset>}" >&2
    exit 1
  fi

  combined_mcp=",$HVA_MCP_ENABLED,$HVA_MCP_DISABLED,"
  seen_mcp=","
  IFS=',' read -r -a mcp_values <<< "$HVA_MCP_ENABLED,$HVA_MCP_DISABLED"
  for mcp_name in "${mcp_values[@]}"; do
    [[ -z "$mcp_name" ]] && continue
    if [[ " ${KNOWN_MCP_KEYS[*]} " != *" $mcp_name "* ]]; then
      echo "unknown MCP entry in HVA config: $mcp_name" >&2
      echo "known MCP entries: ${KNOWN_MCP_KEYS[*]}" >&2
      exit 1
    fi
    if [[ "$seen_mcp" == *",$mcp_name,"* ]]; then
      echo "MCP entry listed more than once or in both enabled/disabled: $mcp_name" >&2
      exit 1
    fi
    seen_mcp+="$mcp_name,"
  done

  for mcp_name in "${KNOWN_MCP_KEYS[@]}"; do
    if [[ "$combined_mcp" != *",$mcp_name,"* ]]; then
      echo "MCP entry is not listed in enabled or disabled: $mcp_name" >&2
      exit 1
    fi
  done
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
      echo "Set LLAMA_MODEL explicitly in config/hva-conf.json." >&2
      exit 1
    fi
  fi

  if [[ ! -f "$LLAMA_MODELS/$LLAMA_MODEL" ]]; then
    echo "Model file does not exist: $LLAMA_MODELS/$LLAMA_MODEL" >&2
    exit 1
  fi
}

env_validate_required() {
  env_validate_common
  env_validate_model
}
