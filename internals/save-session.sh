#!/usr/bin/env bash
# Writes newest Pi session path for workspace state.

set -euo pipefail

session_dir="${HVA_PI_SESSION_DIR:-/hva-state/pi-sessions}"
state_file="${HVA_PI_SESSION_STATE_FILE:-/hva-state/pi_session}"

if [[ ! -d "$session_dir" ]]; then
  exit 0
fi

latest_session="$(
  find "$session_dir" -type f -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | awk 'NR == 1 { print substr($0, index($0, " ") + 1) }'
)"

if [[ -n "$latest_session" ]]; then
  mkdir -p "$(dirname "$state_file")"
  if [[ "$latest_session" == /workspace/* ]]; then
    latest_session="${latest_session#/workspace/}"
  fi
  printf '%s\n' "$latest_session" > "$state_file"
fi
