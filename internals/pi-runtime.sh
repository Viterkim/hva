#!/usr/bin/env bash
# Shared Pi invocation policy for HVA container runtime.

hva_ensure_pi_extension_deps() {
  local image_version stamp_file="/hva/pi/extensions/.ext-deps-version"
  local image_version_file="/hva-ext-deps/.ext-deps-version"

  mkdir -p /hva/pi/extensions
  rm -f /hva/pi/extensions/*.ts
  for file in package.json package-lock.json tsconfig.json agent-guidance.ts common.ts mcp-tools.ts print-exit.ts; do
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
}

hva_pi_base_args() {
  local mode="${1:-interactive}"
  local ext_dir="${HVA_PI_EXTENSIONS_DIR:-/hva/pi/extensions}"
  local skills_dir="${HVA_PI_ACTIVE_SKILLS_DIR:-/hva-state/skills-active}"

  printf '%s\0' \
    --no-context-files \
    --no-extensions \
    --no-skills \
    --extension "$ext_dir/agent-guidance.ts" \
    --extension "$ext_dir/mcp-tools.ts" \
    --skill "$skills_dir"

  if hva_extension_enabled "pi-lens"; then
    printf '%s\0' \
      --no-read-guard \
      --extension "$ext_dir/node_modules/pi-lens/index.ts" \
      --skill "$ext_dir/node_modules/pi-lens/skills"
  fi

  if [[ "$mode" == "print" ]]; then
    printf '%s\0' \
      --extension "$ext_dir/print-exit.ts"
  fi
}

hva_csv_contains() {
  local needle="$1"
  local haystack="${2:-}"
  local value
  IFS=',' read -r -a _hva_csv_values <<< "$haystack"
  for value in "${_hva_csv_values[@]}"; do
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    [[ -z "$value" ]] && continue
    if [[ "$value" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

hva_skill_enabled() {
  hva_csv_contains "$1" "${HVA_SKILLS_ENABLED:-}"
}

hva_extension_enabled() {
  hva_csv_contains "$1" "${HVA_EXTENSIONS_ENABLED:-}"
}

hva_link_skill_dir() {
  local src="$1"
  local dest_root="$2"
  local kind="$3"
  local name="$4"
  mkdir -p "$dest_root/$kind"
  ln -s "$src" "$dest_root/$kind/$name"
}

hva_prepare_active_skills() {
  local source_skills_dir="${HVA_PI_SKILLS_SOURCE_DIR:-/hva/skills}"
  local source_hva_skills_dir="${HVA_PI_HVA_SKILLS_SOURCE_DIR:-/hva/skills-hva}"
  local active_skills_dir="${HVA_PI_ACTIVE_SKILLS_DIR:-/hva-state/skills-active}"
  local skill_dir skill_name

  rm -rf "$active_skills_dir"
  mkdir -p "$active_skills_dir/auto" "$active_skills_dir/manual"

  for skill_dir in "$source_skills_dir"/auto/*; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    [[ "$skill_name" == "mcp" ]] && continue
    hva_skill_enabled "$skill_name" || continue
    hva_link_skill_dir "$skill_dir" "$active_skills_dir" auto "$skill_name"
  done

  for skill_dir in "$source_skills_dir"/manual/*; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    hva_skill_enabled "$skill_name" || continue
    hva_link_skill_dir "$skill_dir" "$active_skills_dir" manual "$skill_name"
  done

  for skill_dir in "$source_hva_skills_dir"/auto/*; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    hva_skill_enabled "$skill_name" || continue
    hva_link_skill_dir "$skill_dir" "$active_skills_dir" auto "$skill_name"
  done

  for skill_dir in "$source_hva_skills_dir"/manual/*; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    hva_skill_enabled "$skill_name" || continue
    hva_link_skill_dir "$skill_dir" "$active_skills_dir" manual "$skill_name"
  done
}

hva_run_pi() {
  local session_file="${1:-}"
  shift || true

  local session_dir="${HVA_PI_SESSION_DIR:-/hva-state/pi-sessions}"
  local mode="interactive"
  local append_system_prompt="${HVA_PI_APPEND_SYSTEM_PROMPT:-}"
  local -a args=()
  local arg

  for arg in "$@"; do
    if [[ "$arg" == "--print" || "$arg" == "-p" ]]; then
      mode="print"
      break
    fi
  done

  hva_prepare_active_skills
  mapfile -d '' -t args < <(hva_pi_base_args "$mode")

  if [[ -n "$session_file" ]]; then
    args+=(--session "$session_file")
  fi

  mkdir -p "$session_dir"
  args+=(--session-dir "$session_dir")
  if [[ -n "$append_system_prompt" ]]; then
    args+=(--append-system-prompt "$append_system_prompt")
  fi
  pi "${args[@]}" "$@"
}
