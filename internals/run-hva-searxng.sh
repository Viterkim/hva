#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

source "$SCRIPT_DIR/../env/env-source.sh"
source "$SCRIPT_DIR/../docker/versions.env"
source "$SCRIPT_DIR/docker.sh"

SEARXNG_CONTAINER="${SEARXNG_CONTAINER:-hva-searxng}"
SEARXNG_HOST_PORT="${SEARXNG_HOST_PORT:-8888}"
SEARXNG_IMAGE="$HVA_V_SEARXNG_IMAGE"
SETTINGS_FILE="$SCRIPT_DIR/searxng-settings.yml"

running_container_id() {
  "${DOCKER[@]}" ps -q --filter "name=^/$SEARXNG_CONTAINER$"
}

container_id() {
  "${DOCKER[@]}" ps -aq --filter "name=^/$SEARXNG_CONTAINER$"
}

ACTION="${1:-start}"

case "$ACTION" in
  start)
    if [[ -n "$(running_container_id)" ]]; then
      echo "searxng already running: $SEARXNG_CONTAINER"
      exit 0
    fi
    existing_id="$(container_id)"
    if [[ -n "$existing_id" ]]; then
      "${DOCKER[@]}" rm "$SEARXNG_CONTAINER" >/dev/null 2>&1 || true
    fi
    echo "starting searxng: $SEARXNG_CONTAINER on port $SEARXNG_HOST_PORT"
    "${DOCKER[@]}" run -d \
      --name "$SEARXNG_CONTAINER" \
      -p "$SEARXNG_HOST_PORT:8080" \
      -v "$SETTINGS_FILE:/etc/searxng/settings.yml:ro" \
      "$SEARXNG_IMAGE" >/dev/null
    ;;
  stop)
    id="$(running_container_id)"
    if [[ -z "$id" ]]; then
      exit 0
    fi
    echo "stopping searxng: $SEARXNG_CONTAINER"
    "${DOCKER[@]}" stop "$SEARXNG_CONTAINER" >/dev/null
    ;;
  status)
    if [[ -n "$(running_container_id)" ]]; then
      echo "searxng running: $SEARXNG_CONTAINER on port $SEARXNG_HOST_PORT"
    else
      echo "searxng not running: $SEARXNG_CONTAINER"
    fi
    ;;
esac
