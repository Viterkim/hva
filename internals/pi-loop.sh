#!/usr/bin/env bash
set -euo pipefail

TASK_FILE="${HVA_LOOP_TASK_FILE:-/workspace/tasks.md}"
TASK_FILE_PROMPT_PATH="$TASK_FILE"
STATE_DIR="${HVA_LOOP_STATE_DIR:-/hva-state/loop}"
STATUS_FILE="$STATE_DIR/status"
STOP_FILE="$STATE_DIR/stop"
SESSION_DIR="${HVA_LOOP_PI_SESSION_DIR:-/hva-state/pi-loop-sessions}"
SESSION_STATE_FILE="$STATE_DIR/pi_session"

# shellcheck disable=SC1091
source /hva/internals/pi-runtime.sh

if [[ "$TASK_FILE_PROMPT_PATH" == /workspace/* ]]; then
  TASK_FILE_PROMPT_PATH="${TASK_FILE_PROMPT_PATH#/workspace/}"
fi

mkdir -p "$STATE_DIR" "$SESSION_DIR"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "task file not found: $TASK_FILE" >&2
  exit 1
fi

first_nonempty() {
  local value=""
  for value in "$@"; do
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done
  return 1
}

trim() {
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<< "${1:-}"
}

read_front_matter_value() {
  local key="$1"
  local line trimmed value
  local in_front_matter=0

  while IFS= read -r line; do
    if (( in_front_matter == 0 )); then
      [[ "$line" == "---" ]] || return 0
      in_front_matter=1
      continue
    fi

    [[ "$line" == "---" ]] && break
    line="${line%%#*}"
    trimmed="$(trim "$line")"
    [[ -z "$trimmed" ]] && continue

    if [[ "$trimmed" =~ ^${key}[[:space:]]*:[[:space:]]*(.*)$ ]]; then
      value="$(trim "${BASH_REMATCH[1]}")"
      printf '%s\n' "$value"
      return 0
    fi
  done < "$TASK_FILE"
}

normalize_non_negative_int() {
  local raw
  raw="$(trim "${1:-}")"
  local fallback="$2"

  if [[ -z "$raw" ]]; then
    printf '%s\n' "$fallback"
    return 0
  fi

  case "$raw" in
    ''|*[!0-9]*)
      echo "loop setting must be a non-negative integer: $raw" >&2
      exit 1
      ;;
    *)
      printf '%s\n' "$raw"
      ;;
  esac
}

normalize_bool() {
  local raw
  raw="$(tr '[:upper:]' '[:lower:]' <<< "$(trim "${1:-}")")"
  local fallback="$2"

  case "$raw" in
    1|true|yes|on) printf '1\n' ;;
    0|false|no|off) printf '0\n' ;;
    '') printf '%s\n' "$fallback" ;;
    *)
      echo "loop setting must be true/false or 1/0: $raw" >&2
      exit 1
      ;;
  esac
}

front_max_iterations="$(read_front_matter_value loop_max_iterations || true)"
front_hours="$(first_nonempty "$(read_front_matter_value loop_hours || true)" "$(read_front_matter_value loop_time_hours || true)" || true)"
front_minutes="$(first_nonempty "$(read_front_matter_value loop_minutes || true)" "$(read_front_matter_value loop_time_minutes || true)" || true)"
front_time_limit="$(read_front_matter_value loop_time_limit || true)"
front_review="$(first_nonempty "$(read_front_matter_value loop_review || true)" "$(read_front_matter_value loop_code_review || true)" || true)"
front_improve="$(first_nonempty "$(read_front_matter_value loop_improve || true)" "$(read_front_matter_value loop_code_improve || true)" || true)"

LOOP_MAX_ITERATIONS="$(
  normalize_non_negative_int \
    "$(first_nonempty "${HVA_LOOP_MAX_ITERATIONS:-}" "${LOOP_MAX:-}" "$front_max_iterations" || true)" \
    "0"
)"
LOOP_HOURS="$(
  normalize_non_negative_int \
    "$front_hours" \
    ""
)"
LOOP_MINUTES="$(
  normalize_non_negative_int \
    "$front_minutes" \
    ""
)"

if [[ -n "${HVA_LOOP_TIME_LIMIT:-}" || -n "${LOOP_TIME_LIMIT:-}" ]]; then
  LOOP_TIME_LIMIT="$(
    normalize_non_negative_int \
      "$(first_nonempty "${HVA_LOOP_TIME_LIMIT:-}" "${LOOP_TIME_LIMIT:-}" || true)" \
      "28800"
  )"
elif [[ -n "$front_time_limit" ]]; then
  LOOP_TIME_LIMIT="$(normalize_non_negative_int "$front_time_limit" "28800")"
elif [[ -n "$LOOP_HOURS" || -n "$LOOP_MINUTES" ]]; then
  LOOP_TIME_LIMIT="$(( (${LOOP_HOURS:-0} * 3600) + (${LOOP_MINUTES:-0} * 60) ))"
else
  LOOP_TIME_LIMIT="28800"
fi

if [[ -z "$LOOP_HOURS" && -z "$LOOP_MINUTES" ]]; then
  LOOP_HOURS="$(( LOOP_TIME_LIMIT / 3600 ))"
  LOOP_MINUTES="$(( (LOOP_TIME_LIMIT % 3600) / 60 ))"
fi

LOOP_REVIEW="$(
  normalize_bool \
    "$(first_nonempty "${HVA_LOOP_REVIEW:-}" "${LOOP_CODE_REVIEW:-}" "$front_review" || true)" \
    "0"
)"
LOOP_IMPROVE="$(
  normalize_bool \
    "$(first_nonempty "${HVA_LOOP_IMPROVE:-}" "$front_improve" || true)" \
    "0"
)"

count_all_checkbox_tasks() {
  grep -Eic '^[[:space:]]*[-*+][[:space:]]+\[[ xX]\][[:space:]]+' "$TASK_FILE" || true
}

count_pending_tasks() {
  awk '
    /^[[:space:]]*[-*+][[:space:]]+\[[[:space:]]*\][[:space:]]+/ && $0 !~ /[[:space:]]+BLOCKED:/ {
      count += 1
    }
    END { print count + 0 }
  ' "$TASK_FILE"
}

count_done_tasks() {
  grep -Eic '^[[:space:]]*[-*+][[:space:]]+\[[xX]\][[:space:]]+' "$TASK_FILE" || true
}

count_blocked_tasks() {
  grep -Eic '^[[:space:]]*[-*+][[:space:]]+\[[[:space:]]*\][[:space:]]+BLOCKED:' "$TASK_FILE" || true
}

next_pending_task() {
  awk '
    /^[[:space:]]*[-*+][[:space:]]+\[[[:space:]]*\][[:space:]]+/ && $0 !~ /[[:space:]]+BLOCKED:/ {
      line = $0
      sub(/^[[:space:]]*[-*+][[:space:]]+\[[[:space:]]*\][[:space:]]+/, "", line)
      print line
      exit
    }
  ' "$TASK_FILE"
}

has_loose_task_lines() {
  awk '
    /^[[:space:]]*[-*+][[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*[-*+][[:space:]]+/, "", line)
      if (line !~ /^\[[ xX]\][[:space:]]+/) {
        found = 1
        exit
      }
    }
    /^[[:space:]]*[0-9]+[.)][[:space:]]+/ {
      found = 1
      exit
    }
    END { exit(found ? 0 : 1) }
  ' "$TASK_FILE"
}

loop_start="$(date +%s)"
iteration=0
phase="idle"
current_target=""
maintenance_phase="review"
first_iteration=1
final_state="finished"
final_message="loop complete"

write_status() {
  local state="$1"
  local phase_name="$2"
  local target="$3"
  local message="$4"
  local elapsed="$(( $(date +%s) - loop_start ))"

  cat > "$STATUS_FILE" <<EOF
state: $state
phase: $phase_name
iteration: $iteration
elapsed_seconds: $elapsed
task_file: $TASK_FILE
loop_max_iterations: $LOOP_MAX_ITERATIONS
loop_time_limit: $LOOP_TIME_LIMIT
loop_hours: ${LOOP_HOURS:-0}
loop_minutes: ${LOOP_MINUTES:-0}
loop_review: $LOOP_REVIEW
loop_improve: $LOOP_IMPROVE
total_checkbox_tasks: $(count_all_checkbox_tasks)
pending_tasks: $(count_pending_tasks)
done_tasks: $(count_done_tasks)
blocked_tasks: $(count_blocked_tasks)
current_target: $target
message: $message
updated_at: $(date -Iseconds)
EOF
}

current_session_file() {
  if [[ -f "$SESSION_STATE_FILE" ]]; then
    local session_file
    session_file="$(tr -d '\r' < "$SESSION_STATE_FILE")"
    if [[ "$session_file" != /* ]]; then
      session_file="/workspace/$session_file"
    fi
    if [[ -f "$session_file" ]]; then
      printf '%s\n' "$session_file"
      return 0
    fi
  fi
  return 1
}

run_prompt() {
  local prompt="$1"
  local current_session=""

  if current_session="$(current_session_file)"; then
    :
  elif (( first_iteration == 1 )) && [[ "${HVA_LOOP_NEW_SESSION:-0}" == "1" ]]; then
    rm -f "$SESSION_STATE_FILE"
  fi

  hva_ensure_pi_extension_deps
  HVA_PI_SESSION_DIR="$SESSION_DIR" hva_run_pi "$current_session" -p "$prompt"
  first_iteration=0
  HVA_PI_SESSION_DIR="$SESSION_DIR" HVA_PI_SESSION_STATE_FILE="$SESSION_STATE_FILE" /hva/internals/save-session.sh || true
}

build_normalize_prompt() {
  cat <<EOF
You are running inside hva loop mode.

Read $TASK_FILE_PROMPT_PATH and normalize it into the standard hva loop format without losing intent.

Rules:
- Keep existing notes and context.
- Keep YAML front matter if present. If it is missing, add it.
- Convert obvious actionable bullets, numbered steps, and sections into checkbox tasks using "- [ ]".
- Preserve clearly finished work as "- [x]".
- Mark blockers as "- [ ] BLOCKED: reason".
- If one task is too large, split it into smaller checkbox tasks.

After normalizing, complete one meaningful pending task, update $TASK_FILE_PROMPT_PATH, run relevant checks, and stop.
EOF
}

build_task_prompt() {
  cat <<EOF
You are running inside hva loop mode.

Read the codebase context you need first. Then read $TASK_FILE_PROMPT_PATH and work on the highest-value pending task.

Rules:
- Keep $TASK_FILE_PROMPT_PATH honest and up to date.
- Mark finished work as "- [x]".
- Mark blockers as "- [ ] BLOCKED: reason".
- If a task is too large, split it into smaller checkbox tasks and complete one meaningful piece.
- Preserve notes and YAML front matter.
- Run relevant tests or checks when possible.

Stop after one meaningful task chunk is complete.
EOF
}

build_review_prompt() {
  cat <<EOF
You are in the review phase of hva loop mode.

Read the entire repository carefully and look for real bugs, broken wiring, risky defaults, unused or contradictory env/config, missing docs, or high-value improvement opportunities.

Update $TASK_FILE_PROMPT_PATH in place:
- append concrete checkbox follow-up items for the best findings
- keep each item specific and actionable
- preserve existing items, notes, and front matter
- if you find nothing credible, leave the file honest and say so in your final reply

Priorities:
- prefer functional bugs, regression tests, broken workflows, risky defaults, missing validation, and real docs gaps
- avoid low-value style churn
- do not add docstring/style/rename/cleanup items unless no higher-value work exists

Do not do broad speculative rewrites in this pass. Prefer recording follow-up work in $TASK_FILE_PROMPT_PATH.
Stop after the review pass is recorded.
EOF
}

build_improve_prompt() {
  cat <<EOF
You are in the improve phase of hva loop mode.

Read $TASK_FILE_PROMPT_PATH and the repository. Pick the highest-value pending improvement you can justify, or create one if an obvious high-confidence issue is missing.

Implement one meaningful improvement.
Then update $TASK_FILE_PROMPT_PATH:
- mark the finished item as "- [x]"
- split oversized work into smaller follow-up checkbox tasks
- mark blockers as "- [ ] BLOCKED: reason"

Priorities:
- prefer bug fixes, tests, validation, and workflow fixes over style-only work
- if both functional and style tasks exist, ignore the style task for now

Run relevant checks when possible. Stop after one meaningful improvement.
EOF
}

echo "=== hva loop ==="
echo "task file: $TASK_FILE"
echo "max iterations: $LOOP_MAX_ITERATIONS (0 = no limit)"
echo "time limit: ${LOOP_HOURS:-0}h ${LOOP_MINUTES:-0}m = $LOOP_TIME_LIMIT seconds (0 = no limit)"
echo "review phase: $LOOP_REVIEW"
echo "improve phase: $LOOP_IMPROVE"
echo

write_status "running" "startup" "" "loop starting"

while true; do
  if [[ -f "$STOP_FILE" ]]; then
    final_state="stopped"
    final_message="stop requested"
    rm -f "$STOP_FILE"
    break
  fi

  elapsed="$(( $(date +%s) - loop_start ))"
  if (( LOOP_TIME_LIMIT > 0 && elapsed >= LOOP_TIME_LIMIT )); then
    final_state="finished"
    final_message="time limit reached after the current iteration"
    break
  fi

  if (( LOOP_MAX_ITERATIONS > 0 && iteration >= LOOP_MAX_ITERATIONS )); then
    final_state="finished"
    final_message="max iterations reached"
    break
  fi

  total_checkbox_tasks="$(count_all_checkbox_tasks)"
  pending_tasks="$(count_pending_tasks)"
  phase=""
  current_target=""
  next_maintenance_phase="$maintenance_phase"
  prompt=""

  if (( pending_tasks > 0 )); then
    phase="task"
    current_target="$(next_pending_task)"
    prompt="$(build_task_prompt)"
    next_maintenance_phase="review"
  elif (( total_checkbox_tasks == 0 )) && has_loose_task_lines; then
    phase="normalize"
    current_target="normalize tasks.md and begin the queue"
    prompt="$(build_normalize_prompt)"
    next_maintenance_phase="review"
  elif (( LOOP_REVIEW == 1 )) && [[ "$maintenance_phase" == "review" || "$LOOP_IMPROVE" == "0" ]]; then
    phase="review"
    current_target="review the repository and queue follow-up work"
    prompt="$(build_review_prompt)"
    if (( LOOP_IMPROVE == 1 )); then
      next_maintenance_phase="improve"
    else
      next_maintenance_phase="review"
    fi
  elif (( LOOP_IMPROVE == 1 )); then
    phase="improve"
    current_target="implement one meaningful improvement"
    prompt="$(build_improve_prompt)"
    if (( LOOP_REVIEW == 1 )); then
      next_maintenance_phase="review"
    else
      next_maintenance_phase="improve"
    fi
  else
    final_state="finished"
    final_message="no pending tasks and no maintenance phases enabled"
    break
  fi

  iteration=$((iteration + 1))
  echo "--- iteration $iteration ---"
  echo "phase: $phase"
  if [[ -n "$current_target" ]]; then
    echo "target: $current_target"
  fi
  echo

  write_status "running" "$phase" "$current_target" "iteration starting"

  if run_prompt "$prompt"; then
    write_status "running" "$phase" "$current_target" "iteration complete"
  else
    write_status "running" "$phase" "$current_target" "pi exited with an error; continuing"
    echo "iteration failed: $phase" >&2
  fi

  if (( "$(count_pending_tasks)" == 0 )) && (( "$(count_all_checkbox_tasks)" > 0 )) && (( LOOP_REVIEW == 0 )) && (( LOOP_IMPROVE == 0 )); then
    final_state="finished"
    final_message="no pending tasks and no maintenance phases enabled"
    break
  fi

  maintenance_phase="$next_maintenance_phase"
  echo
done

final_phase="$phase"
if [[ -z "$final_phase" ]]; then
  case "$final_state" in
    stopped) final_phase="stopped" ;;
    *) final_phase="idle" ;;
  esac
fi

write_status "$final_state" "$final_phase" "$current_target" "$final_message"

echo "=== loop finished ==="
echo "state: $final_state"
echo "message: $final_message"
echo "iterations: $iteration"
echo "pending tasks: $(count_pending_tasks)"
