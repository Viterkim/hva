#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
HVA_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd -P)"
config_path="${HVA_CHECK_CONFIG:-${HVA_CONFIG:-$HVA_ROOT/config/hva-conf.json}}"

runs="${HVA_CHECK_RUNS:-3}"
prefix="${HVA_CHECK_PREFIX:-prompt-check}"
timeout_seconds="${HVA_CHECK_TIMEOUT:-120}"
prompt_mode="${HVA_CHECK_RUNTIME_PROMPT_MODE:-normal}"
skip_all_injects="${HVA_CHECK_SKIP_ALL_INJECTS:-${HVA_CHECK_SKIP_INJECT:-1}}"
new_hard="${HVA_CHECK_NEW_HARD:-0}"
restart_llama="${HVA_CHECK_RESTART_LLAMA:-1}"
hard_inject="${HVA_CHECK_HARD_INJECT:-}"
llama_model="${HVA_CHECK_LLAMA_MODEL:-}"
keep_dirs="${HVA_CHECK_KEEP_DIRS:-0}"
expect_rust_project="${HVA_CHECK_EXPECT_RUST_PROJECT:-auto}"
expect_bingo_file="${HVA_CHECK_EXPECT_BINGO_FILE:-auto}"
bingo_file="${HVA_CHECK_BINGO_FILE:-bingo-test-file.txt}"
bingo_text="${HVA_CHECK_BINGO_TEXT:-85}"
print_llama_health="${HVA_CHECK_PRINT_LLAMA_HEALTH:-1}"
health_tail="${HVA_CHECK_HEALTH_TAIL:-5000}"
fail_fast="${HVA_CHECK_FAIL_FAST:-1}"

usage() {
  cat <<EOF
Usage:
  hva --check-system-prompt

Environment:
  HVA_CHECK_RUNS=3
  HVA_CHECK_PREFIX=prompt-check
  HVA_CHECK_TIMEOUT=120
  HVA_CHECK_RUNTIME_PROMPT_MODE=normal|none|nudge|force
  HVA_CHECK_SKIP_ALL_INJECTS=0|1
  HVA_CHECK_LLAMA_MODEL=model.gguf
  HVA_CHECK_HARD_INJECT=skill-name
  HVA_CHECK_PROMPT='custom prompt'
  HVA_CHECK_PROMPT_TEMPLATE='custom prompt with {dir}'
  HVA_CHECK_EXPECT_RUST_PROJECT=auto|0|1
  HVA_CHECK_EXPECT_BINGO_FILE=auto|0|1
  HVA_CHECK_BINGO_FILE=bingo-test-file.txt
  HVA_CHECK_BINGO_TEXT=85
  HVA_CHECK_PRINT_LLAMA_HEALTH=0|1
  HVA_CHECK_HEALTH_TAIL=5000
  HVA_CHECK_FAIL_FAST=0|1
  HVA_CHECK_KEEP_DIRS=0|1
  HVA_CHECK_NEW_HARD=1
  HVA_CHECK_RESTART_LLAMA=0|1
EOF
}

case "${1:-}" in
  "")
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

if [[ ! -f "$config_path" ]]; then
  echo "config file does not exist: $config_path" >&2
  echo "run ./scripts/hva once or set HVA_CHECK_CONFIG to an existing config file." >&2
  exit 1
fi

case "$prompt_mode" in
  normal|none|nudge|force) ;;
  *)
    echo "HVA_CHECK_RUNTIME_PROMPT_MODE must be normal, none, nudge, or force: $prompt_mode" >&2
    exit 1
    ;;
esac

case "$skip_all_injects" in
  0|1) ;;
  *)
    echo "HVA_CHECK_SKIP_ALL_INJECTS must be 0 or 1: $skip_all_injects" >&2
    exit 1
    ;;
esac

case "$restart_llama" in
  0|1) ;;
  *)
    echo "HVA_CHECK_RESTART_LLAMA must be 0 or 1: $restart_llama" >&2
    exit 1
    ;;
esac

case "$keep_dirs" in
  0|1) ;;
  *)
    echo "HVA_CHECK_KEEP_DIRS must be 0 or 1: $keep_dirs" >&2
    exit 1
    ;;
esac

case "$expect_rust_project" in
  auto|0|1) ;;
  *)
    echo "HVA_CHECK_EXPECT_RUST_PROJECT must be auto, 0, or 1: $expect_rust_project" >&2
    exit 1
    ;;
esac

case "$expect_bingo_file" in
  auto|0|1) ;;
  *)
    echo "HVA_CHECK_EXPECT_BINGO_FILE must be auto, 0, or 1: $expect_bingo_file" >&2
    exit 1
    ;;
esac

case "$print_llama_health" in
  0|1) ;;
  *)
    echo "HVA_CHECK_PRINT_LLAMA_HEALTH must be 0 or 1: $print_llama_health" >&2
    exit 1
    ;;
esac

case "$fail_fast" in
  0|1) ;;
  *)
    echo "HVA_CHECK_FAIL_FAST must be 0 or 1: $fail_fast" >&2
    exit 1
    ;;
esac

case "$health_tail" in
  ''|*[!0-9]*)
    echo "HVA_CHECK_HEALTH_TAIL must be a number: $health_tail" >&2
    exit 1
    ;;
esac

if ! [[ "$runs" =~ ^[0-9]+$ ]] || [[ "$runs" == "0" ]]; then
  echo "HVA_CHECK_RUNS must be a positive integer: $runs" >&2
  exit 1
fi

if [[ "$new_hard" == "1" ]]; then
  session_flag="--new-hard"
else
  session_flag="--new"
fi

cfg="$(mktemp)"
created_dirs=()

cleanup() {
  rm -f "$cfg"
  if [[ "$keep_dirs" != "1" ]] && ((${#created_dirs[@]} > 0)); then
    rm -rf -- "${created_dirs[@]}"
  fi
}
trap cleanup EXIT

print_tree() {
  local dir="$1"

  if [[ ! -d "$dir" ]]; then
    echo "(missing)"
    return
  fi

  if command -v tree >/dev/null 2>&1; then
    tree -a -I target "$dir"
    return
  fi

  find "$dir" \
    -path "$dir/target" -prune -o \
    -print | sort
}

build_prompt() {
  local dir="$1"
  if [[ -n "${HVA_CHECK_PROMPT_TEMPLATE:-}" ]]; then
    printf '%s' "${HVA_CHECK_PROMPT_TEMPLATE//\{dir\}/$dir}"
    return
  fi
  if [[ -n "${HVA_CHECK_PROMPT:-}" ]]; then
    printf '%s' "$HVA_CHECK_PROMPT"
    return
  fi
  printf 'make a subfolder and init a new rust project called %s. also create %s inside that folder with exactly this text and nothing else: %s' "$dir" "$bingo_file" "$bingo_text"
}

should_expect_rust_project() {
  case "$expect_rust_project" in
    1) return 0 ;;
    0) return 1 ;;
    auto)
      [[ -z "${HVA_CHECK_PROMPT:-}" && -z "${HVA_CHECK_PROMPT_TEMPLATE:-}" ]]
      ;;
  esac
}

should_expect_bingo_file() {
  case "$expect_bingo_file" in
    1) return 0 ;;
    0) return 1 ;;
    auto)
      [[ -z "${HVA_CHECK_PROMPT:-}" && -z "${HVA_CHECK_PROMPT_TEMPLATE:-}" ]]
      ;;
  esac
}

validate_rust_project() {
  local dir="$1"
  local cargo_name edition

  if [[ ! -f "$dir/Cargo.toml" ]]; then
    echo "RESULT: rust project missing expected Cargo.toml" >&2
    return 1
  fi

  if [[ ! -f "$dir/src/main.rs" ]] && ! { [[ -f "$dir/src/lib.rs" ]] && compgen -G "$dir/src/bin/*.rs" >/dev/null; }; then
    echo "RESULT: rust project missing expected src/main.rs or src/lib.rs plus src/bin/*.rs" >&2
    return 1
  fi

  cargo_name="$(sed -n 's/^name[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$dir/Cargo.toml" | head -1)"
  edition="$(sed -n 's/^edition[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$dir/Cargo.toml" | head -1)"
  if [[ -z "$cargo_name" || -z "$edition" ]]; then
    echo "RESULT: Cargo.toml missing package name or edition" >&2
    return 1
  fi

  echo "RESULT: rust project ok (package=$cargo_name edition=$edition)"
}

validate_bingo_file() {
  local dir="$1"
  local path="$dir/$bingo_file"
  local contents

  if [[ ! -f "$path" ]]; then
    echo "RESULT: bingo file missing ($bingo_file)" >&2
    return 1
  fi

  contents="$(tr -d '\r\n' < "$path")"
  if [[ "$contents" != "$bingo_text" ]]; then
    echo "RESULT: bingo file wrong (expected=$bingo_text actual=$contents)" >&2
    return 1
  fi

  echo "RESULT: bingo file ok ($bingo_file=$bingo_text)"
}

print_llama_speed_summary() {
  if [[ "$print_llama_health" != "1" ]]; then
    return
  fi

  echo "--- LLAMA HEALTH ---"
  HVA_CONFIG="$cfg" "$HVA_ROOT/internals/healthcheck.sh" --debug-cache --tail "$health_tail" || true
}

cd "$HVA_ROOT"

jq_filter='.HVA_RUNTIME_PROMPT_MODE=$mode | .HVA_SKIP_ALL_INJECTS=$skip'
jq_args=(--arg mode "$prompt_mode" --arg skip "$skip_all_injects")

if [[ -n "$llama_model" ]]; then
  jq_filter+=' | .LLAMA_MODEL=$model'
  jq_args+=(--arg model "$llama_model")
fi

if [[ -n "$hard_inject" ]]; then
  jq_filter+=' | .HVA_HARD_INJECT_SKILLS=$hard | .HVA_SOFT_INJECT_SKILLS=(.HVA_SOFT_INJECT_SKILLS | split(",") | map(select(. != $hard)) | join(",")) | .HVA_DONT_INJECT_SKILLS=(.HVA_DONT_INJECT_SKILLS | split(",") | map(select(. != $hard)) | join(","))'
  jq_args+=(--arg hard "$hard_inject")
fi

jq "${jq_args[@]}" "$jq_filter" "$config_path" > "$cfg"

echo "HVA system prompt check"
echo "workspace: $HVA_ROOT"
echo "config path: $config_path"
echo "runs: $runs"
echo "runtime prompt mode: $prompt_mode"
echo "skip all injects: $skip_all_injects"
echo "llama model: ${llama_model:-(config default)}"
echo "hard inject: ${hard_inject:-(none)}"
echo "session flag: $session_flag"
echo "restart llama: $restart_llama"
echo "expect rust project: $expect_rust_project"
echo "expect bingo file: $expect_bingo_file"
echo "fail fast: $fail_fast"
echo "keep dirs: $keep_dirs"
echo "default test mode is: fresh Pi session every run plus llama restart every run."
echo "use HVA_CHECK_NEW_HARD=1 as well if you also want a fresh dev container every run."
echo

for n in $(seq 1 "$runs"); do
  dir="${prefix}-${n}"
  msg="$(build_prompt "$dir")"
  run_status=0
  created_dirs+=("$dir")
  rm -rf "$dir"

  echo "=== RUN:$n ==="
  HVA_CONFIG="$cfg" \
  HVA_RESTART_LLAMA="$restart_llama" \
  timeout "$timeout_seconds" \
    ./scripts/hva "$session_flag" --msg "$msg" | sed -n '1,120p'

  echo "--- TREE:$dir ---"
  print_tree "$dir"
  if should_expect_rust_project; then
    validate_rust_project "$dir" || run_status=1
  fi
  if should_expect_bingo_file; then
    validate_bingo_file "$dir" || run_status=1
  fi
  print_llama_speed_summary
  if (( run_status != 0 )); then
    echo "RESULT: run failed"
    if [[ "$fail_fast" == "1" ]]; then
      exit "$run_status"
    fi
  else
    echo "RESULT: run ok"
  fi
  echo
done
