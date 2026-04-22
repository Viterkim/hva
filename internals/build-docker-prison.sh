#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

source "$SCRIPT_DIR/docker.sh"

ENV_SOURCE="${SCRIPT_DIR}/../env/env-source.sh"
if [[ -f "$ENV_SOURCE" ]]; then
    # shellcheck source=../env/env-source.sh
    source "$ENV_SOURCE"
fi

VERSIONS_FILE="${VERSIONS_FILE:-$SCRIPT_DIR/../docker/versions.env}"

# shellcheck source=../docker/versions.env
source "$VERSIONS_FILE"

# Validate every entry in versions.env has a value
while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    if [[ -z "$value" ]]; then
        echo "error: ${key} has no value in docker/versions.env" >&2
        exit 1
    fi
done < "$VERSIONS_FILE"

# Build --build-arg list from versions.env
VERSION_ARGS=()
while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    VERSION_ARGS+=(--build-arg "$line")
done < "$VERSIONS_FILE"

USER_UID="${USER_UID:-$(id -u)}"
USER_GID="${USER_GID:-$(id -g)}"
USERNAME="${USERNAME:-dev}"
HVA_CSHARP="${HVA_CSHARP:-false}"
IMAGE_NAME="${IMAGE_NAME:-hva-safeprison}"
FORCE_REBUILD=0

case "${1:-}" in
    --force)
        FORCE_REBUILD=1
        shift
        ;;
    "")
        ;;
    *)
        echo "unknown argument: $1" >&2
        echo "usage: $0 [--force]" >&2
        exit 1
        ;;
esac

case "${HVA_CSHARP}" in
    true|false) ;;
    *) echo "error: HVA_CSHARP must be true or false, got: ${HVA_CSHARP}" >&2; exit 1 ;;
esac
DOCKER_CONTEXT="${DOCKER_CONTEXT:-$SCRIPT_DIR/../docker}"
DEV_IMAGE_SOURCE_HASH="$(
  {
    cd "$DOCKER_CONTEXT"
    find . -type f -print0 | sort -z | xargs -0 sha256sum
    sha256sum "$VERSIONS_FILE" | awk '{print $1}'
    printf 'HVA_CSHARP=%s\n' "$HVA_CSHARP"
  } | sha256sum | awk '{print $1}'
)"
CURRENT_IMAGE_HASH="$("${DOCKER[@]}" image inspect "$IMAGE_NAME" --format '{{ index .Config.Labels "dev.hva.source-hash" }}' 2>/dev/null || true)"

if [[ "${HVA_REBUILD:-0}" != "1" && "$FORCE_REBUILD" != "1" && -n "$CURRENT_IMAGE_HASH" && "$CURRENT_IMAGE_HASH" == "$DEV_IMAGE_SOURCE_HASH" ]]; then
    echo "dev image up to date: $IMAGE_NAME"
    exit 0
fi

if [[ -z "$CURRENT_IMAGE_HASH" ]]; then
    echo "building missing dev image: $IMAGE_NAME"
elif [[ "${HVA_REBUILD:-0}" == "1" || "$FORCE_REBUILD" == "1" ]]; then
    echo "force rebuilding dev image: $IMAGE_NAME"
else
    echo "rebuilding outdated dev image: $IMAGE_NAME"
fi

DOCKER_BUILDKIT=1 "${DOCKER[@]}" build \
  --build-arg "USERNAME=${USERNAME}" \
  --build-arg "USER_UID=${USER_UID}" \
  --build-arg "USER_GID=${USER_GID}" \
  --build-arg "HVA_CSHARP=${HVA_CSHARP}" \
  --build-arg "DEV_IMAGE_SOURCE_HASH=${DEV_IMAGE_SOURCE_HASH}" \
  "${VERSION_ARGS[@]}" \
  -f "$DOCKER_CONTEXT/Dockerfile.safeprison" \
  -t "$IMAGE_NAME" \
  "$DOCKER_CONTEXT"
