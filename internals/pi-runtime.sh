#!/usr/bin/env bash
# Shared Pi invocation policy for HVA container runtime.

hva_ensure_pi_extension_deps() {
  local image_version stamp_file="/hva/pi/extensions/.ext-deps-version"
  local image_version_file="/hva-ext-deps/.ext-deps-version"

  mkdir -p /hva/pi/extensions
  rm -f /hva/pi/extensions/*.ts
  for file in package.json package-lock.json tsconfig.json agent-guidance.ts common.ts mcp-tools.ts print-exit.ts patch-pi-lens.mjs; do
    cp -f "/hva/pi/extensions-src/$file" "/hva/pi/extensions/$file"
  done

  image_version="$(cat "$image_version_file" 2>/dev/null || echo "none")"

  if [[ ! -d /hva/pi/extensions/node_modules ]] || \
     [[ "$(cat "$stamp_file" 2>/dev/null || echo "")" != "$image_version" ]]; then
    echo "syncing extension deps from image..."
    rm -rf /hva/pi/extensions/node_modules
    cp -r /hva-ext-deps/node_modules /hva/pi/extensions/node_modules
    printf '%s\n' "$image_version" > "$stamp_file"
  fi

  node /hva/pi/extensions/patch-pi-lens.mjs /hva/pi/extensions
}

hva_pi_base_args() {
  local mode="${1:-interactive}"
  local ext_dir="${HVA_PI_EXTENSIONS_DIR:-/hva/pi/extensions}"
  local skills_dir="${HVA_PI_SKILLS_DIR:-/hva/pi/skills}"

  printf '%s\0' \
    --no-context-files \
    --no-extensions \
    --no-skills \
    --extension "$ext_dir/agent-guidance.ts" \
    --extension "$ext_dir/mcp-tools.ts" \
    --skill "$skills_dir/hva-runtime" \
    --extension "$ext_dir/node_modules/pi-lens/index.ts" \
    --skill "$ext_dir/node_modules/pi-lens/skills"

  if [[ "$mode" == "print" ]]; then
    printf '%s\0' \
      --extension "$ext_dir/print-exit.ts"
  fi
}

hva_run_pi() {
  local session_file="${1:-}"
  shift || true

  local session_dir="${HVA_PI_SESSION_DIR:-/hva-state/pi-sessions}"
  local mode="interactive"
  local pi_lens_startup_mode="${PI_LENS_STARTUP_MODE:-quick}"
  local -a args=()
  local arg

  for arg in "$@"; do
    if [[ "$arg" == "--print" || "$arg" == "-p" ]]; then
      mode="print"
      break
    fi
  done

  mapfile -d '' -t args < <(hva_pi_base_args "$mode")

  if [[ -n "$session_file" ]]; then
    args+=(--session "$session_file")
  fi

  args+=(--session-dir "$session_dir")
  PI_LENS_STARTUP_MODE="$pi_lens_startup_mode" pi "${args[@]}" "$@"
}
