#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-preview}"
TARGET_INPUT="${2:-.}"

WORKSPACE_ROOT="${HVA_READ_REPO_WORKSPACE_ROOT:-/workspace}"
STATE_DIR="${HVA_READ_REPO_STATE_DIR:-/hva-state/read-repo}"
MAX_FILE_BYTES=$((5 * 1024 * 1024))
WARN_FILE_BYTES=$((100 * 1024))

IGNORE_NAMES=(
  ".git"
  ".gitmodules"
  ".gitattributes"
  ".github"
  ".gitlab"
  ".hva-state"
  ".pi"
  ".pi-lens"
  "node_modules"
  "vendor"
  ".pnpm-store"
  ".yarn"
  ".npm"
  "target"
  "dist"
  "build"
  "out"
  "release"
  "debug"
  ".output"
  "*.map"
  ".next"
  ".nuxt"
  ".svelte-kit"
  ".angular"
  ".expo"
  ".vercel"
  ".netlify"
  ".cache"
  ".turbo"
  ".parcel-cache"
  ".vite"
  ".eslintcache"
  "__pycache__"
  "pycache"
  ".pytest_cache"
  ".mypy_cache"
  ".ruff_cache"
  ".cargo"
  ".gradle"
  ".env"
  ".env.local"
  ".direnv"
  ".clipboardignore"
  ".idea"
  ".vscode"
  "tmp"
  "temp"
  "temp-out"
  "mock_fs"
  "mock-fs"
  "coverage"
  ".nyc_output"
  ".coverage"
  ".venv"
  "venv"
  ".terraform"
  "*.lock"
  "*lock.json"
  "*lock.yaml"
  "*.hex"
  "*.bin"
  "*.wasm"
  "*.exe"
  "*.dll"
  "*.so"
  "*.dylib"
  "*.min.js"
  "*.min.css"
  "*.png"
  "*.jpg"
  "*.jpeg"
  "*.gif"
  "*.webp"
  "*.svg"
  "*.mp4"
  "*.mov"
  "*.webm"
  "*.gguf"
  "*.ggml"
  "*.safetensors"
  "*.ckpt"
  "*.pt"
  "*.pth"
  "*.onnx"
  ".vibe-state"
)

usage() {
  cat >&2 <<'EOF'
usage:
  read-repo.sh preview [path]
  read-repo.sh build [path]
  read-repo.sh ignore-add [path] <pattern> [pattern...]
  read-repo.sh cleanup [path]
EOF
  exit 1
}

die() {
  echo "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

human_bytes() {
  local bytes="${1:-0}"
  local units=(B KB MB GB TB)
  local value="$bytes"
  local unit_index=0

  while (( value >= 1024 && unit_index < ${#units[@]} - 1 )); do
    value=$((value / 1024))
    unit_index=$((unit_index + 1))
  done

  printf '%s %s' "$value" "${units[$unit_index]}"
}

normalize_rel() {
  local rel="$1"
  rel="${rel#./}"
  printf '%s' "$rel"
}

ensure_within_workspace() {
  local input="$1"
  local resolved

  resolved="$(realpath "$input" 2>/dev/null)" || die "path does not exist: $input"
  case "$resolved" in
    "$WORKSPACE_ROOT"|"$WORKSPACE_ROOT"/*) ;;
    *) die "path must stay inside $WORKSPACE_ROOT: $resolved" ;;
  esac

  printf '%s' "$resolved"
}

build_ignore_file() {
  : > "$IGNORE_FILE"
  local pattern
  for pattern in "${IGNORE_NAMES[@]}"; do
    printf '%s\n' "$pattern" >> "$IGNORE_FILE"
  done
  if [[ -f "$PROJECT_CLIPBOARDIGNORE_FILE" ]]; then
    cat "$PROJECT_CLIPBOARDIGNORE_FILE" >> "$IGNORE_FILE"
  fi
  if [[ -f "$CLIPBOARDIGNORE_FILE" ]]; then
    cat "$CLIPBOARDIGNORE_FILE" >> "$IGNORE_FILE"
  fi
}

write_summary() {
  {
    echo
    echo "Included files:"
    while IFS=$'\t' read -r _bytes lines chars rel; do
      printf '%7s lines  %8s chars  %s\n' "$lines" "$chars" "$rel"
    done < "$INCLUDED_FILE"

    if [[ -s "$SKIPPED_BY_SIZE_FILE" ]]; then
      echo
      echo "Skipped oversize files:"
      while IFS=$'\t' read -r bytes rel; do
        printf '%8s  %s\n' "$(human_bytes "$bytes")" "$rel"
      done < "$SKIPPED_BY_SIZE_FILE"
    fi

    if [[ -s "$PROJECT_CLIPBOARDIGNORE_FILE" || -s "$CLIPBOARDIGNORE_FILE" ]]; then
      echo
      echo "Ignore rules:"
      if [[ -s "$PROJECT_CLIPBOARDIGNORE_FILE" ]]; then
        sed 's/^/  /' "$PROJECT_CLIPBOARDIGNORE_FILE"
      fi
      if [[ -s "$CLIPBOARDIGNORE_FILE" ]]; then
        sed 's/^/  /' "$CLIPBOARDIGNORE_FILE"
      fi
    fi

    echo
    echo "Included $FILE_COUNT file(s)"
    echo "Total lines: $TOTAL_LINES"
    echo "Total chars: $TOTAL_CHARS"
    echo "Estimated tokens: $ESTIMATED_TOKENS"
    if [[ "$CONTEXT_WINDOW" =~ ^[0-9]+$ ]] && (( CONTEXT_WINDOW > 0 )); then
      echo "Context window: $CONTEXT_WINDOW"
    fi
    echo "Context status: $CONTEXT_STATUS"
  } > "$SUMMARY_FILE"
}

write_output() {
  {
    echo "target: $DISPLAY_TARGET"
    echo "included_files: $FILE_COUNT"
    echo "skipped_oversize_files: $SKIPPED_COUNT"
    echo "total_chars: $TOTAL_CHARS"
    echo "estimated_tokens: $ESTIMATED_TOKENS"
    echo "context_window: $CONTEXT_WINDOW"
    echo "context_status: $CONTEXT_STATUS"
    echo "---"
    while IFS=$'\t' read -r bytes lines chars rel; do
      echo "file: $rel"
      echo "  lines: $lines"
      echo "  chars: $chars"
      echo "  bytes: $bytes"
      echo "---"
      cat -- "$TARGET_ROOT_ABS/$rel"
      echo
      echo "---"
    done < "$INCLUDED_FILE"
  } > "$OUTPUT_FILE"
}

require_cmd rg
require_cmd realpath
require_cmd sort
require_cmd wc

case "$MODE" in
  preview|build|ignore-add|cleanup) ;;
  *) usage ;;
esac

mkdir -p "$STATE_DIR"
TMP_DIR="$(mktemp -d "$STATE_DIR/tmp.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

IGNORE_FILE="$TMP_DIR/ignore.txt"
INCLUDED_FILE="$TMP_DIR/included.tsv"
SKIPPED_FILE="$TMP_DIR/skipped.tsv"
INCLUDED_BY_SIZE_FILE="$TMP_DIR/included-by-size.tsv"
SKIPPED_BY_SIZE_FILE="$TMP_DIR/skipped-by-size.tsv"

TARGET_ABS="$(ensure_within_workspace "$TARGET_INPUT")"
DISPLAY_TARGET="$TARGET_INPUT"
TARGET_SCOPE_ABS="$TARGET_ABS"
if [[ -f "$TARGET_ABS" ]]; then
  TARGET_SCOPE_ABS="$(dirname "$TARGET_ABS")"
fi
TARGET_ID="$(printf '%s\n' "$TARGET_SCOPE_ABS" | sha256sum | cut -c1-16)"
TARGET_STATE_DIR="$STATE_DIR/$TARGET_ID"
mkdir -p "$TARGET_STATE_DIR"
SUMMARY_FILE="$TARGET_STATE_DIR/summary.txt"
OUTPUT_FILE="$TARGET_STATE_DIR/output.txt"
CLIPBOARDIGNORE_FILE="$TARGET_STATE_DIR/.clipboardignore"
PROJECT_CLIPBOARDIGNORE_FILE="$TARGET_SCOPE_ABS/.clipboardignore"
IGNORE_ENTRY_COUNT=0

if [[ "$MODE" == "ignore-add" ]]; then
  shift 2 || true
  [[ $# -gt 0 ]] || die "ignore-add needs at least one pattern"
  {
    [[ -f "$CLIPBOARDIGNORE_FILE" ]] && cat "$CLIPBOARDIGNORE_FILE"
    printf '%s\n' "$@"
  } | awk 'NF && !seen[$0]++' > "$TMP_DIR/clipboardignore.new"
  mv "$TMP_DIR/clipboardignore.new" "$CLIPBOARDIGNORE_FILE"
  echo "state_clipboardignore: $CLIPBOARDIGNORE_FILE"
  echo "clipboardignore_entries: $(grep -cve '^[[:space:]]*$' "$CLIPBOARDIGNORE_FILE" 2>/dev/null || true)"
  echo
  cat "$CLIPBOARDIGNORE_FILE"
  exit 0
fi

if [[ "$MODE" == "cleanup" ]]; then
  rm -f "$SUMMARY_FILE" "$OUTPUT_FILE"
  find "$TARGET_STATE_DIR" -mindepth 1 -maxdepth 1 -type d -name 'tmp.*' -exec rm -rf {} + 2>/dev/null || true
  if [[ ! -f "$CLIPBOARDIGNORE_FILE" ]]; then
    rmdir "$TARGET_STATE_DIR" 2>/dev/null || true
  fi
  echo "cleaned: $TARGET_STATE_DIR"
  exit 0
fi

build_ignore_file

FILE_COUNT=0
SKIPPED_COUNT=0
TOTAL_LINES=0
TOTAL_CHARS=0
TOTAL_BYTES=0
ESTIMATED_TOKENS=0
CONTEXT_WINDOW="${LLAMA_CONTEXT_SIZE:-unknown}"
CONTEXT_STATUS="unknown"

: > "$INCLUDED_FILE"
: > "$SKIPPED_FILE"

if [[ -f "$TARGET_ABS" ]]; then
  TARGET_ROOT_ABS="$(dirname "$TARGET_ABS")"
  rel="$(basename "$TARGET_ABS")"
  included=0
  while IFS= read -r -d '' candidate; do
    candidate="$(normalize_rel "$candidate")"
    if [[ "$candidate" == "$rel" ]]; then
      included=1
      break
    fi
  done < <(
    cd "$TARGET_ROOT_ABS"
    rg --files \
      --hidden \
      --no-require-git \
      --null \
      --color=never \
      --ignore-file "$IGNORE_FILE" \
      . | LC_ALL=C sort -z
  )
  if (( included != 1 )); then
    die "ignored by built-in rules, .gitignore, or .clipboardignore: $TARGET_INPUT"
  fi
  bytes="$(wc -c < "$TARGET_ABS" | tr -d ' ')"
  if (( bytes > MAX_FILE_BYTES )); then
    printf '%s\t%s\n' "$bytes" "$rel" >> "$SKIPPED_FILE"
    SKIPPED_COUNT=1
  else
    lines="$(wc -l < "$TARGET_ABS" | tr -d ' ')"
    chars="$(wc -c < "$TARGET_ABS" | tr -d ' ')"
    printf '%s\t%s\t%s\t%s\n' "$bytes" "$lines" "$chars" "$rel" >> "$INCLUDED_FILE"
    FILE_COUNT=1
    TOTAL_LINES="$lines"
    TOTAL_CHARS="$chars"
    TOTAL_BYTES="$bytes"
  fi
elif [[ -d "$TARGET_ABS" ]]; then
  TARGET_ROOT_ABS="$TARGET_ABS"
  while IFS= read -r -d '' rel; do
    rel="$(normalize_rel "$rel")"
    [[ -n "$rel" ]] || continue

    abs="$TARGET_ROOT_ABS/$rel"
    bytes="$(wc -c < "$abs" | tr -d ' ')"
    if (( bytes > MAX_FILE_BYTES )); then
      printf '%s\t%s\n' "$bytes" "$rel" >> "$SKIPPED_FILE"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      continue
    fi

    lines="$(wc -l < "$abs" | tr -d ' ')"
    chars="$(wc -c < "$abs" | tr -d ' ')"

    printf '%s\t%s\t%s\t%s\n' "$bytes" "$lines" "$chars" "$rel" >> "$INCLUDED_FILE"

    FILE_COUNT=$((FILE_COUNT + 1))
    TOTAL_LINES=$((TOTAL_LINES + lines))
    TOTAL_CHARS=$((TOTAL_CHARS + chars))
    TOTAL_BYTES=$((TOTAL_BYTES + bytes))
  done < <(
    cd "$TARGET_ROOT_ABS"
    rg --files \
      --hidden \
      --no-require-git \
      --null \
      --color=never \
      --ignore-file "$IGNORE_FILE" \
      . | LC_ALL=C sort -z
  )
else
  die "not a regular file or directory: $TARGET_INPUT"
fi

if (( FILE_COUNT == 0 )); then
  if (( SKIPPED_COUNT > 0 )); then
    die "all matched files were skipped because they were larger than $(human_bytes "$MAX_FILE_BYTES")"
  fi
  die "no files found for: $TARGET_INPUT"
fi

ESTIMATED_TOKENS=$(( (TOTAL_CHARS + 3) / 4 ))
if [[ "$CONTEXT_WINDOW" =~ ^[0-9]+$ ]] && (( CONTEXT_WINDOW > 0 )); then
  if (( ESTIMATED_TOKENS > CONTEXT_WINDOW * 8 / 10 )); then
    CONTEXT_STATUS="warning"
  else
    CONTEXT_STATUS="fits"
  fi
fi
IGNORE_ENTRY_COUNT="$(
  {
    [[ -f "$PROJECT_CLIPBOARDIGNORE_FILE" ]] && cat "$PROJECT_CLIPBOARDIGNORE_FILE"
    [[ -f "$CLIPBOARDIGNORE_FILE" ]] && cat "$CLIPBOARDIGNORE_FILE"
  } | grep -cve '^[[:space:]]*$' 2>/dev/null || true
)"

sort -t $'\t' -k4,4 "$INCLUDED_FILE" > "$TMP_DIR/included-sorted.tsv"
mv "$TMP_DIR/included-sorted.tsv" "$INCLUDED_FILE"
sort -t $'\t' -nrk1,1 "$INCLUDED_FILE" > "$INCLUDED_BY_SIZE_FILE"
sort -t $'\t' -nrk1,1 "$SKIPPED_FILE" > "$SKIPPED_BY_SIZE_FILE"

write_summary

if [[ "$MODE" == "preview" ]]; then
  cat "$SUMMARY_FILE"
  exit 0
fi

write_output
OUTPUT_TOTAL_LINES="$(wc -l < "$OUTPUT_FILE" | tr -d ' ')"

{
  echo "target: $DISPLAY_TARGET"
  echo "output_file: $OUTPUT_FILE"
  echo "output_lines: $OUTPUT_TOTAL_LINES"
  echo "included_files: $FILE_COUNT"
  echo "skipped_oversize_files: $SKIPPED_COUNT"
  echo "estimated_tokens: $ESTIMATED_TOKENS"
  echo "context_window: $CONTEXT_WINDOW"
  echo "context_status: $CONTEXT_STATUS"
  echo "next_step: use read on output_file and keep following offset hints until complete"
}
