#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
HVA_ROOT="${HVA_ROOT:-$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd -P)}"
SAMPLE="$HVA_ROOT/config/hva-conf.json.sample"
TARGET="${HVA_CONFIG:-$HVA_ROOT/config/hva-conf.json}"
QUIET=0

case "${1:-}" in
  "")
    ;;
  --quiet)
    QUIET=1
    ;;
  -h|--help|help)
    cat <<EOF
Usage:
  sync-config.sh [--quiet]

Create config/hva-conf.json if missing, or merge in any sample keys that were
added later. Unknown keys still fail.
EOF
    exit 0
    ;;
  *)
    echo "unknown argument: $1" >&2
    exit 1
    ;;
esac

if [[ ! -f "$SAMPLE" ]]; then
  echo "missing sample config: $SAMPLE" >&2
  exit 1
fi

unknown_target_keys() {
  local target_path="$1"

  jq -r --slurpfile sample "$SAMPLE" '
    ([keys_unsorted[]] - ($sample[0] | keys_unsorted))[]?
  ' "$target_path"
}

if [[ -f "$TARGET" ]]; then
  tmp="$(mktemp "${TARGET}.XXXXXX")"
  jq -S -s '.[0] * .[1]' "$SAMPLE" "$TARGET" > "$tmp"
  unknown_keys="$(unknown_target_keys "$TARGET")"
  if cmp -s "$tmp" "$TARGET"; then
    rm -f "$tmp"
    if [[ -n "$unknown_keys" ]]; then
      echo "unknown keys in config: $TARGET" >&2
      while IFS= read -r key; do
        [[ -n "$key" ]] && echo "  $key" >&2
      done <<< "$unknown_keys"
      exit 1
    fi
    if (( QUIET == 0 )); then
      echo "config exists: $TARGET"
    fi
    exit 0
  fi
  mv "$tmp" "$TARGET"
  if [[ -n "$unknown_keys" ]]; then
    echo "updated config with missing sample keys: $TARGET" >&2
    echo "unknown keys in config: $TARGET" >&2
    while IFS= read -r key; do
      [[ -n "$key" ]] && echo "  $key" >&2
    done <<< "$unknown_keys"
    exit 1
  fi
  echo "updated config with missing sample keys: $TARGET"
  exit 0
fi

mkdir -p "$(dirname "$TARGET")"
install -m 0644 "$SAMPLE" "$TARGET"
echo "created config: $TARGET"
