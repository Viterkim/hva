#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

usage() {
  cat <<EOF
Usage:
  run-hva-searxng.sh [start|stop|status]
EOF
}

ACTION="${1:-start}"

case "$ACTION" in
  -h|--help|help)
    usage
    exit 0
    ;;
  start|stop|status)
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
    stop|status)
      SEARXNG_CONTAINER="${SEARXNG_CONTAINER:-hva-searxng}"
      SEARXNG_HOST_PORT="${SEARXNG_HOST_PORT:-8888}"
      ;;
    *)
      # shellcheck disable=SC1091
      source "$SCRIPT_DIR/load-config.sh"
      ;;
  esac
}

load_config_or_service_defaults
source "$SCRIPT_DIR/../docker/versions.env"
source "$SCRIPT_DIR/docker.sh"
source "$SCRIPT_DIR/docker-network.sh"

SEARXNG_CONTAINER="${SEARXNG_CONTAINER:-hva-searxng}"
SEARXNG_HOST_PORT="${SEARXNG_HOST_PORT:-8888}"
SEARXNG_IMAGE="$HVA_V_SEARXNG_IMAGE"
SETTINGS_FILE="$SCRIPT_DIR/searxng-settings.yml"
LIMITER_FILE="$SCRIPT_DIR/searxng-limiter.toml"

running_container_id() {
  "${DOCKER[@]}" ps -q --filter "name=^/$SEARXNG_CONTAINER$"
}

container_id() {
  "${DOCKER[@]}" ps -aq --filter "name=^/$SEARXNG_CONTAINER$"
}

create_container() {
  local network_mode="$1"
  local -a docker_args=(--name "$SEARXNG_CONTAINER")

  if [[ "$network_mode" == "host" ]]; then
    docker_args+=(
      --network host
      -e GRANIAN_HOST=127.0.0.1
      -e GRANIAN_PORT="$SEARXNG_HOST_PORT"
    )
  else
    docker_args+=(
      --network "$network_mode"
      -p "$SEARXNG_HOST_PORT:8080"
    )
  fi

  docker_args+=(
    --tmpfs "/etc/searxng:rw,nosuid,nodev,size=1m"
    --tmpfs "/var/cache/searxng:rw,nosuid,nodev,size=64m"
    -v "$SETTINGS_FILE:/hva-searxng/settings.yml:ro"
    -v "$LIMITER_FILE:/hva-searxng/limiter.toml:ro"
    --entrypoint sh
  )

  "${DOCKER[@]}" create "${docker_args[@]}" "$SEARXNG_IMAGE" -lc '
cp /hva-searxng/settings.yml /etc/searxng/settings.yml
cp /hva-searxng/limiter.toml /etc/searxng/limiter.toml
exec /usr/local/searxng/entrypoint.sh
' >/dev/null
}

case "$ACTION" in
  start)
    NETWORK_MODE="$(hva_detect_docker_network_mode)"
    if [[ -n "$(running_container_id)" ]]; then
      echo "searxng already running: $SEARXNG_CONTAINER"
      exit 0
    fi
    existing_id="$(container_id)"
    if [[ -n "$existing_id" ]]; then
      "${DOCKER[@]}" rm "$SEARXNG_CONTAINER" >/dev/null 2>&1 || true
    fi
    echo "starting searxng: $SEARXNG_CONTAINER on port $SEARXNG_HOST_PORT via network $NETWORK_MODE"
    create_container "$NETWORK_MODE"
    if ! "${DOCKER[@]}" start "$SEARXNG_CONTAINER" >/dev/null; then
      "${DOCKER[@]}" rm -f "$SEARXNG_CONTAINER" >/dev/null 2>&1 || true
      exit 1
    fi
    ;;
  stop)
    id="$(running_container_id)"
    if [[ -n "$id" ]]; then
      echo "stopping searxng: $SEARXNG_CONTAINER"
      "${DOCKER[@]}" stop "$SEARXNG_CONTAINER" >/dev/null
    fi
    existing_id="$(container_id)"
    if [[ -n "$existing_id" ]]; then
      "${DOCKER[@]}" rm "$SEARXNG_CONTAINER" >/dev/null 2>&1 || true
    fi
    ;;
  status)
    if [[ -n "$(running_container_id)" ]]; then
      echo "searxng running: $SEARXNG_CONTAINER on port $SEARXNG_HOST_PORT"
    else
      echo "searxng not running: $SEARXNG_CONTAINER"
    fi
    ;;
esac
