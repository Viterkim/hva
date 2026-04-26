#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
HVA_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd -P)"

usage() {
  cat <<EOF
Usage:
  cleanup-docker.sh [--apply] [--volumes] [--global-build-cache] [--all-build-cache]

By default this prints Docker storage status only.

Options:
  --apply              remove only obvious HVA-owned stopped containers and dangling HVA images
  --volumes            with --apply, prune anonymous unused Docker volumes too
  --global-build-cache with --apply, also prune global BuildKit cache to HVA_DOCKER_BUILD_CACHE_MAX_USED (default 40gb)
  --all-build-cache    with --global-build-cache, include internal/frontend build cache
EOF
}

APPLY=0
GLOBAL_BUILD_CACHE=0
ALL_BUILD_CACHE=0
PRUNE_VOLUMES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --global-build-cache|--build-cache)
      GLOBAL_BUILD_CACHE=1
      shift
      ;;
    --all-build-cache)
      ALL_BUILD_CACHE=1
      shift
      ;;
    --volumes)
      PRUNE_VOLUMES=1
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# shellcheck disable=SC1091
source "$HVA_ROOT/internals/docker.sh"

config_path="${HVA_CONFIG:-$HVA_ROOT/config/hva-conf.json}"
if [[ -f "$config_path" ]]; then
  # shellcheck disable=SC1091
  source "$HVA_ROOT/internals/load-config.sh"
fi

LLAMA_CONTAINER="${LLAMA_CONTAINER:-hva-llama-server}"
SEARXNG_CONTAINER="${SEARXNG_CONTAINER:-hva-searxng}"

echo "docker storage:"
"${DOCKER[@]}" system df

echo
echo "hva repo state:"
if [[ -e "$HVA_ROOT/.hva-state" ]]; then
  du -sh "$HVA_ROOT/.hva-state"
else
  echo "none"
fi

echo
echo "unused docker volumes (global; named volumes may be unrelated to HVA):"
"${DOCKER[@]}" volume ls -q --filter dangling=true | sed 's/^/  /' || true

if (( APPLY == 0 )); then
  echo
  echo "dry run only."
  echo "HVA-only cleanup: hva --cleanup-docker --apply"
  echo "Global BuildKit cache cleanup: hva --cleanup-docker --apply --global-build-cache"
  exit 0
fi

echo
echo "removing stopped HVA containers..."
for name in hva-dev "$LLAMA_CONTAINER" "$SEARXNG_CONTAINER"; do
  if "${DOCKER[@]}" ps -aq --filter "name=^/${name}$" --filter status=exited | grep -q .; then
    "${DOCKER[@]}" rm "$name" >/dev/null 2>&1 || true
    echo "removed container: $name"
  fi
done

echo
echo "removing dangling HVA images..."
"${DOCKER[@]}" image ls --format '{{.Repository}}:{{.Tag}} {{.ID}}' \
  | awk '$1 ~ /^hva-/ && $1 ~ /:<none>$/ { print $2 }' \
  | xargs -r "${DOCKER[@]}" image rm

if (( GLOBAL_BUILD_CACHE == 1 )); then
  echo
  echo "pruning global BuildKit cache..."
  buildx_args=(prune -f --max-used-space "${HVA_DOCKER_BUILD_CACHE_MAX_USED:-40gb}")
  if (( ALL_BUILD_CACHE == 1 )); then
    buildx_args+=(--all)
  fi
  "${DOCKER[@]}" buildx "${buildx_args[@]}"
else
  echo
  echo "skipping global BuildKit cache. add --global-build-cache to prune it."
fi

if (( PRUNE_VOLUMES == 1 )); then
  echo
  echo "pruning anonymous unused Docker volumes..."
  "${DOCKER[@]}" volume ls -q --filter dangling=true \
    | grep -E '^[0-9a-f]{64}$' \
    | xargs -r "${DOCKER[@]}" volume rm
fi

echo
echo "docker storage after cleanup:"
"${DOCKER[@]}" system df
