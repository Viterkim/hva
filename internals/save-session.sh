#!/usr/bin/env bash
# Writes the most recently accessed nanocoder session ID for /workspace to the
# workspace state file.  Called from the container entrypoint after nanocoder
# exits so the next hva run can auto-resume the same session.

sessions_json="${NANOCODER_DATA_DIR}/sessions/sessions.json"
state_file="/workspace/.hva-state/nanocoder_session"

if [ ! -f "$sessions_json" ] || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

session_id="$(
  jq -r '[.[] | select(.workingDirectory == "/workspace")] |
         sort_by(.lastAccessedAt) | last | .id // empty' \
    "$sessions_json" 2>/dev/null || true
)"

if [ -n "$session_id" ]; then
  mkdir -p /workspace/.hva-state
  printf '%s\n' "$session_id" > "$state_file"
fi
