#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

usage() {
  cat <<EOF
Usage:
  run-hva-llama-cpp.sh [run|daemon|restart|stop|status|logs] [--model FILE] [--ncmoe N] [-- ...]
EOF
}

ACTION="${1:-run}"
case "$ACTION" in
  run|daemon|restart|stop|status|logs)
    if [[ $# -gt 0 ]]; then
      shift
    fi
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "unknown action: $ACTION" >&2
    usage >&2
    exit 1
    ;;
esac

load_config_or_service_defaults() {
  local config_path="${HVA_CONFIG:-$SCRIPT_DIR/../config/hva-conf.json}"

  if [[ -f "$config_path" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/load-config.sh"
    return
  fi

  case "$ACTION" in
    stop|status|logs)
      LLAMA_CONTAINER="${LLAMA_CONTAINER:-hva-llama-server}"
      ;;
    *)
      # shellcheck disable=SC1091
      source "$SCRIPT_DIR/load-config.sh"
      ;;
  esac
}

load_config_or_service_defaults

source "$SCRIPT_DIR/docker.sh"
source "$SCRIPT_DIR/docker-network.sh"
source "$SCRIPT_DIR/../docker/versions.env"

case "$ACTION" in
  stop)
    if [[ -n "$("${DOCKER[@]}" ps -q --filter "name=^/$LLAMA_CONTAINER$")" ]]; then
      echo "stopping llama server: $LLAMA_CONTAINER"
      "${DOCKER[@]}" stop "$LLAMA_CONTAINER" >/dev/null 2>&1 || true
    else
      echo "llama server is not running: $LLAMA_CONTAINER"
    fi
    existing_id="$("${DOCKER[@]}" ps -aq --filter "name=^/$LLAMA_CONTAINER$")"
    if [[ -n "$existing_id" ]]; then
      "${DOCKER[@]}" rm "$LLAMA_CONTAINER" >/dev/null 2>&1 || true
    fi
    exit 0
    ;;
  status)
    if [[ -n "$("${DOCKER[@]}" ps -q --filter "name=^/$LLAMA_CONTAINER$")" ]]; then
      "${DOCKER[@]}" ps --filter "name=^/$LLAMA_CONTAINER$"
    else
      echo "llama server is not running: $LLAMA_CONTAINER"
    fi
    exit 0
    ;;
  logs)
    "${DOCKER[@]}" logs "$LLAMA_CONTAINER"
    exit 0
    ;;
esac

LLAMA_IMAGE="${LLAMA_IMAGE:-}"

# If no override, select image based on detected/configured GPU vendor.
# This runs before detect_gpu_vendor() is defined; the function is used later.
# We defer image selection until after vendor detection below.

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      if [[ $# -lt 2 ]]; then
        echo "--model requires a GGUF filename" >&2
        exit 1
      fi
      LLAMA_MODEL="$2"
      shift 2
      ;;
    --ncmoe)
      if [[ $# -lt 2 ]]; then
        echo "--ncmoe requires a numeric value" >&2
        exit 1
      fi
      LLAMA_NCMOE="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

case "$LLAMA_NCMOE" in
  ''|*[!0-9]*)
    echo "LLAMA_NCMOE must be a number: $LLAMA_NCMOE" >&2
    exit 1
    ;;
esac

llama_fit_args=(--fit on)
if [[ -n "${LLAMA_AUTOFIT_TOKENS:-}" && "${LLAMA_AUTOFIT_TOKENS:-}" != "0" ]]; then
  llama_fit_args+=(-fitt "$LLAMA_AUTOFIT_TOKENS")
else
  llama_fit_args+=(-ncmoe "$LLAMA_NCMOE")
fi

env_validate_common

running_container_id() {
  "${DOCKER[@]}" ps -q --filter "name=^/$LLAMA_CONTAINER$"
}

detect_gpu_vendor() {
  if [[ "${LLAMA_GPU_VENDOR:-auto}" != "auto" ]]; then
    printf '%s\n' "${LLAMA_GPU_VENDOR:-}"
    return 0
  fi

  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    printf 'nvidia\n'
    return 0
  fi
  if command -v rocm-smi >/dev/null 2>&1 && rocm-smi >/dev/null 2>&1; then
    printf 'amd\n'
    return 0
  fi
  if command -v clinfo >/dev/null 2>&1 && clinfo 2>/dev/null | grep -qi 'intel'; then
    printf 'intel\n'
    return 0
  fi
  for vendor_file in /sys/class/drm/card*/device/vendor; do
    [[ -f "$vendor_file" ]] || continue
    vendor="$(tr '[:upper:]' '[:lower:]' < "$vendor_file")"
    case "$vendor" in
      0x10de) printf 'nvidia\n'; return 0 ;;
      0x1002|0x1022) printf 'amd\n'; return 0 ;;
      0x8086) printf 'intel\n'; return 0 ;;
    esac
  done
  printf '\n'
}

host_platform_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'amd64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    *) uname -m ;;
  esac
}

container_id() {
  "${DOCKER[@]}" ps -aq --filter "name=^/$LLAMA_CONTAINER$"
}

case "$ACTION" in
  stop)
    if [[ -n "$(running_container_id)" ]]; then
      echo "stopping llama server: $LLAMA_CONTAINER"
      "${DOCKER[@]}" stop "$LLAMA_CONTAINER" >/dev/null 2>&1 || true
    else
      echo "llama server is not running: $LLAMA_CONTAINER"
    fi
    existing_id="$(container_id)"
    if [[ -n "$existing_id" ]]; then
      "${DOCKER[@]}" rm "$LLAMA_CONTAINER" >/dev/null 2>&1 || true
    fi
    exit 0
    ;;
  status)
    if [[ -n "$(running_container_id)" ]]; then
      "${DOCKER[@]}" ps --filter "name=^/$LLAMA_CONTAINER$"
    else
      echo "llama server is not running: $LLAMA_CONTAINER"
    fi
    exit 0
    ;;
  logs)
    "${DOCKER[@]}" logs "$LLAMA_CONTAINER"
    exit 0
    ;;
  daemon)
    LLAMA_DAEMON=1
    if [[ -n "$(running_container_id)" ]]; then
      echo "llama server already running: $LLAMA_CONTAINER"
      exit 0
    fi
    existing_id="$(container_id)"
    if [[ -n "$existing_id" ]]; then
      "${DOCKER[@]}" rm "$LLAMA_CONTAINER" >/dev/null 2>&1 || true
    fi
    ;;
  restart)
    LLAMA_DAEMON=1
    if [[ -n "$(running_container_id)" ]]; then
      echo "restarting llama server: $LLAMA_CONTAINER"
      "${DOCKER[@]}" stop "$LLAMA_CONTAINER" >/dev/null 2>&1 || true
    else
      echo "llama server is not running: $LLAMA_CONTAINER"
    fi
    existing_id="$(container_id)"
    if [[ -n "$existing_id" ]]; then
      "${DOCKER[@]}" rm "$LLAMA_CONTAINER" >/dev/null 2>&1 || true
    fi
    ;;
esac

env_validate_model

: "${LLAMA_MODELS:?LLAMA_MODELS must be set by HVA config}"
NETWORK_MODE="$(hva_detect_docker_network_mode)"
LLAMA_CONTAINER_PORT="8080"

if [[ "$NETWORK_MODE" == "host" ]]; then
  LLAMA_CONTAINER_PORT="$LLAMA_HOST_PORT"
fi

llama_reasoning_args=(--reasoning off)
if [[ "${LLAMA_ENABLE_THINKING:-0}" == "1" ]]; then
  llama_reasoning_args=(
    --reasoning on
    --reasoning-budget "$LLAMA_REASONING_BUDGET"
    --reasoning-format deepseek
    --reasoning-budget-message "Answer now:"
  )
fi

llama_chat_template_args=()
if [[ "${LLAMA_PRESERVE_THINKING:-0}" == "1" ]]; then
  llama_chat_template_args=(--chat-template-kwargs '{"preserve_thinking": true}')
fi

docker_args=(
  --rm
  -v "$LLAMA_MODELS:/models:ro"
)

gpu_vendor="$(detect_gpu_vendor)"
host_arch="$(host_platform_arch)"

if [[ -z "$LLAMA_IMAGE" ]]; then
  case "$gpu_vendor" in
    nvidia)   LLAMA_IMAGE="$HVA_V_LLAMA_CPP_IMAGE_CUDA" ;;
    amd)      LLAMA_IMAGE="$HVA_V_LLAMA_CPP_IMAGE_ROCM" ;;
    intel)    LLAMA_IMAGE="$HVA_V_LLAMA_CPP_IMAGE_VULKAN" ;;
    *)        LLAMA_IMAGE="$HVA_V_LLAMA_CPP_IMAGE_CPU" ;;
  esac
fi

if [[ "$gpu_vendor" == "amd" && "$host_arch" != "amd64" ]]; then
  echo "ROCm llama.cpp image is only available for linux/amd64; host arch is $host_arch." >&2
  echo "Set LLAMA_GPU_VENDOR=cpu/none, use a Vulkan-capable path, or run on amd64." >&2
  exit 1
fi

case "$gpu_vendor" in
  nvidia)
    docker_args+=(--gpus all)
    ;;
  amd)
    docker_args+=(--device /dev/kfd --device /dev/dri --group-add video --group-add render)
    ;;
  intel)
    docker_args+=(--device /dev/dri --group-add video --group-add render)
    ;;
  ""|none|cpu)
    ;;
  *)
    echo "unknown LLAMA_GPU_VENDOR: $gpu_vendor" >&2
    exit 1
    ;;
esac

if [[ "$NETWORK_MODE" == "host" ]]; then
  docker_args+=(--network host)
else
  docker_args+=(--network "$NETWORK_MODE" -p "$LLAMA_HOST_PORT:8080")
fi

if [[ "${LLAMA_DAEMON:-0}" == "1" ]]; then
  echo "starting llama server: $LLAMA_CONTAINER on port $LLAMA_HOST_PORT via network $NETWORK_MODE gpu=${gpu_vendor:-none}"
  docker_args=(-d --name "$LLAMA_CONTAINER" "${docker_args[@]}")
else
  docker_args=(-it "${docker_args[@]}")
fi

run_llama() {
  "${DOCKER[@]}" run "${docker_args[@]}" \
    "$LLAMA_IMAGE" \
    -m "/models/$LLAMA_MODEL" \
    --alias "$LLAMA_MODEL_ALIAS" \
    -c "$LLAMA_CONTEXT_SIZE" \
    --kv-unified \
    -ngl auto \
    "${llama_fit_args[@]}" \
    -np 1 \
    -fa on \
    -ctk q8_0 \
    -ctv q8_0 \
    --jinja \
    "${llama_chat_template_args[@]}" \
    "${llama_reasoning_args[@]}" \
    --metrics \
    --host 0.0.0.0 \
    --port "$LLAMA_CONTAINER_PORT" \
    --temperature "$LLAMA_TEMPERATURE" \
    --top-p "$LLAMA_TOP_P" \
    --top-k "$LLAMA_TOP_K" \
    --min-p "$LLAMA_MIN_P" \
    --presence-penalty "$LLAMA_PRESENCE_PENALTY" \
    --repeat-penalty "$LLAMA_REPEAT_PENALTY" \
    "$@"
}

if [[ "${LLAMA_DAEMON:-0}" == "1" ]]; then
  run_llama "$@" >/dev/null
else
  run_llama "$@"
fi
