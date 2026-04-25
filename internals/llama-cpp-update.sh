#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

source "$SCRIPT_DIR/docker.sh"
VERSIONS_FILE="${VERSIONS_FILE:-$SCRIPT_DIR/../docker/versions.env}"

# shellcheck source=../docker/versions.env
source "$VERSIONS_FILE"

declare -A LLAMA_BACKENDS=(
  [CUDA]="$HVA_V_LLAMA_CPP_IMAGE_CUDA"
  [ROCm]="$HVA_V_LLAMA_CPP_IMAGE_ROCM"
  [Vulkan]="$HVA_V_LLAMA_CPP_IMAGE_VULKAN"
  [CPU]="$HVA_V_LLAMA_CPP_IMAGE_CPU"
)
declare -A LLAMA_VAR_NAMES=(
  [CUDA]="HVA_V_LLAMA_CPP_IMAGE_CUDA"
  [ROCm]="HVA_V_LLAMA_CPP_IMAGE_ROCM"
  [Vulkan]="HVA_V_LLAMA_CPP_IMAGE_VULKAN"
  [CPU]="HVA_V_LLAMA_CPP_IMAGE_CPU"
)

any_updated=0

for backend in CUDA ROCm Vulkan CPU; do
  current_ref="${LLAMA_BACKENDS[$backend]}"
  tag_ref="${current_ref%@*}"
  var_name="${LLAMA_VAR_NAMES[$backend]}"

  latest_digest="$(
    "${DOCKER[@]}" buildx imagetools inspect "$tag_ref" 2>/dev/null \
      | awk '/^Digest:/ { print $2; exit }'
  )"

  if [[ -z "$latest_digest" ]]; then
    echo "could not resolve latest digest for $backend: $tag_ref" >&2
    continue
  fi

  latest_ref="${tag_ref}@${latest_digest}"

  if [[ "$latest_ref" != "$current_ref" ]]; then
    sed -i "s|^${var_name}=.*$|${var_name}=${latest_ref}|" "$VERSIONS_FILE"
    echo "updated $backend: $latest_ref"
    any_updated=1
  else
    echo "$backend already up to date: $latest_ref"
  fi

  echo "pulling $backend image: $latest_ref"
  "${DOCKER[@]}" pull "$latest_ref"
done

if (( any_updated == 1 )); then
  echo
  echo "restart llama to use new image:"
  echo "  HVA_RESTART_LLAMA=1 hva"
fi
