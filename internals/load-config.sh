#!/usr/bin/env bash
# Load HVA config.

if [[ -z "${HVA_ROOT:-}" ]]; then
  HVA_LOAD_CONFIG_SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
  HVA_ROOT="$(cd "$(dirname "$HVA_LOAD_CONFIG_SCRIPT")/.." && pwd -P)"
fi

HVA_CONFIG="${HVA_CONFIG:-$HVA_ROOT/config/hva-conf.json}"
HVA_CONFIG_SAMPLE="$HVA_ROOT/config/hva-conf.json.sample"

if [[ -f "$HVA_CONFIG" ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to read HVA_CONFIG: $HVA_CONFIG" >&2
    exit 1
  fi

  unknown_keys="$(jq -r --slurpfile sample "$HVA_CONFIG_SAMPLE" '
    ([keys_unsorted[]] - ($sample[0] | keys_unsorted))[]?
  ' "$HVA_CONFIG")"
  if [[ -n "$unknown_keys" ]]; then
    echo "unknown keys in HVA config: $HVA_CONFIG" >&2
    while IFS= read -r key; do
      [[ -n "$key" ]] && echo "  $key" >&2
    done <<< "$unknown_keys"
    echo "Run: $HVA_ROOT/internals/sync-config.sh" >&2
    exit 1
  fi

  while IFS='=' read -r key value; do
    if [[ "$key" =~ ^[A-Z0-9_]+$ ]]; then
      printf -v "$key" '%s' "$value"
      export "${key?}"
    fi
  done < <(jq -r 'to_entries[] | select(.value | type != "object" and type != "array") | "\(.key)=\(.value)"' "$HVA_CONFIG")
else
  echo "HVA config missing: $HVA_CONFIG" >&2
  echo "Create it with: $HVA_ROOT/internals/sync-config.sh" >&2
  exit 1
fi

if [[ -n "${LLAMA_MODELS:-}" && "$LLAMA_MODELS" != /* ]]; then
  LLAMA_MODELS="$HVA_ROOT/$LLAMA_MODELS"
  export LLAMA_MODELS
fi

hva_load_secrets() {
  local secrets_file

  if [[ "${HVA_LOAD_SECRETS:-1}" != "1" ]]; then
    return
  fi

  secrets_file="${HVA_SECRETS:-$HVA_ROOT/config/hva-secrets.json}"
  if [[ -f "$secrets_file" ]]; then
    if ! command -v jq >/dev/null 2>&1; then
      echo "jq is required to read HVA secrets: $secrets_file" >&2
      exit 1
    fi

    while IFS='=' read -r key value; do
      if [[ "$key" =~ ^[A-Z0-9_]+$ && -n "$value" ]]; then
        printf -v "$key" '%s' "$value"
        export "${key?}"
      fi
    done < <(
      jq -r '
        to_entries[]
        | .key as $key
        | (
            if (.value | type) == "string" then .value
            elif (.value | type) == "object" then (.value.value? // empty)
            else empty
            end
          ) as $secret
        | select(($secret | type) == "string" and $secret != "")
        | "\($key)=\($secret)"
      ' "$secrets_file"
    )
  fi
}

hva_normalize_github_tokens() {
  if [[ -z "${GITHUB_TOKEN-}" && -n "${GITHUB_PERSONAL_ACCESS_TOKEN-}" ]]; then
    export GITHUB_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
  fi

  if [[ -z "${GITHUB_PERSONAL_ACCESS_TOKEN-}" && -n "${GITHUB_TOKEN-}" ]]; then
    export GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN"
  fi
}

# shellcheck disable=SC1091
source "$HVA_ROOT/env/env-validate.sh"
