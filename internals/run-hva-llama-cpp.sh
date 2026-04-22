#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

source "$SCRIPT_DIR/../env/env-source.sh"
source "$SCRIPT_DIR/../env/env-validate.sh"

source "$SCRIPT_DIR/docker.sh"
source "$SCRIPT_DIR/../docker/versions.env"

ACTION="${1:-run}"
case "$ACTION" in
  run|daemon|restart|stop|status|logs)
    if [[ $# -gt 0 ]]; then
      shift
    fi
    ;;
  *)
    ACTION=run
    ;;
esac

LLAMA_IMAGE="$HVA_V_LLAMA_CPP_IMAGE"

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

: "${LLAMA_MODELS:?LLAMA_MODELS must be set by env/env-source.sh}"

docker_args=(
  --rm
  --gpus all
  -p "$LLAMA_HOST_PORT:8080"
  -v "$LLAMA_MODELS:/models:ro"
)

if [[ "${LLAMA_DAEMON:-0}" == "1" ]]; then
  echo "starting llama server: $LLAMA_CONTAINER on port $LLAMA_HOST_PORT"
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
    -ngl auto \
    "${llama_fit_args[@]}" \
    -np 1 \
    -fa on \
    -ctk q8_0 \
    -ctv q8_0 \
    --chat-template-kwargs '{"preserve_thinking": true, "enable_thinking": true}'  \
    --jinja \
    --reasoning auto \
    --reasoning-budget "$LLAMA_REASONING_BUDGET" \
    --reasoning-format deepseek \
    --reasoning-budget-message "Answer now:" \
    --metrics \
    --host 0.0.0.0 \
    --port 8080 \
    --temperature 0.61 \
    --top-p 0.94 \
    --top-k 19 \
    --min-p 0.0 \
    --presence-penalty 0.0 \
    --repeat-penalty 1.0 \
    "$@"
}

if [[ "${LLAMA_DAEMON:-0}" == "1" ]]; then
  run_llama "$@" >/dev/null
else
  run_llama "$@"
fi
