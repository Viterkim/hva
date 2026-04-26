#!/usr/bin/env bash

DOCKER_NETWORK_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOCKER_NETWORK_ROOT="$(cd "$(dirname "$DOCKER_NETWORK_SCRIPT_PATH")/.." && pwd -P)"

source "$DOCKER_NETWORK_ROOT/docker/versions.env"

hva_docker_network_state_file() {
  printf '%s\n' "${HVA_DOCKER_NETWORK_STATE_FILE:-$DOCKER_NETWORK_ROOT/.hva-state/docker-network-mode}"
}

hva_requested_docker_network() {
  printf '%s\n' "${LLAMA_NETWORK:-hva-net}"
}

hva_write_docker_network_mode() {
  local mode="$1"
  local state_file
  state_file="$(hva_docker_network_state_file)"
  mkdir -p "$(dirname "$state_file")"
  printf '%s\n' "$mode" > "$state_file"
}

hva_read_docker_network_mode() {
  local state_file
  state_file="$(hva_docker_network_state_file)"
  if [[ -f "$state_file" ]]; then
    tr -d '\r' < "$state_file"
  fi
}

hva_ensure_docker_network_exists() {
  local mode="$1"

  case "$mode" in
    ""|bridge|host|none)
      return 0
      ;;
  esac

  if ! "${DOCKER[@]}" network inspect "$mode" >/dev/null 2>&1; then
    "${DOCKER[@]}" network create "$mode" >/dev/null
  fi
}

hva_detect_docker_network_mode() {
  local requested cached probe_image probe_log

  if [[ -n "${HVA_DOCKER_NETWORK_MODE:-}" ]]; then
    requested="$HVA_DOCKER_NETWORK_MODE"
    hva_ensure_docker_network_exists "$requested"
    printf '%s\n' "$requested"
    return 0
  fi

  requested="$(hva_requested_docker_network)"
  cached="$(hva_read_docker_network_mode || true)"

  if [[ -n "$cached" ]]; then
    if [[ "$cached" == "$requested" ]]; then
      hva_ensure_docker_network_exists "$cached"
      printf '%s\n' "$cached"
      return 0
    fi
  fi

  case "$requested" in
    host|none)
      hva_write_docker_network_mode "$requested"
      printf '%s\n' "$requested"
      return 0
      ;;
  esac

  hva_ensure_docker_network_exists "$requested"

  probe_image="${HVA_DOCKER_NETWORK_PROBE_IMAGE:-$HVA_V_UBUNTU_BASE_IMAGE}"
  probe_log="$(mktemp "${TMPDIR:-/tmp}/hva-docker-network.XXXXXX")"

  if "${DOCKER[@]}" run --rm --network "$requested" "$probe_image" true >/dev/null 2>"$probe_log"; then
    rm -f "$probe_log"
    hva_write_docker_network_mode "$requested"
    printf '%s\n' "$requested"
    return 0
  fi

  if grep -Eq 'failed to add the host .* pair interfaces: operation not supported' "$probe_log"; then
    rm -f "$probe_log"
    hva_write_docker_network_mode host
    printf '%s\n' host
    return 0
  fi

  cat "$probe_log" >&2
  rm -f "$probe_log"
  return 1
}

hva_llama_base_url_for_network() {
  local mode="$1"
  local host_port="$2"

  if [[ "$mode" == "host" ]]; then
    printf 'http://127.0.0.1:%s/v1\n' "$host_port"
  else
    printf 'http://host.docker.internal:%s/v1\n' "$host_port"
  fi
}

hva_searxng_url_for_network() {
  local mode="$1"
  local host_port="$2"

  if [[ "$mode" == "host" ]]; then
    printf 'http://127.0.0.1:%s\n' "$host_port"
  else
    printf 'http://host.docker.internal:%s\n' "$host_port"
  fi
}
