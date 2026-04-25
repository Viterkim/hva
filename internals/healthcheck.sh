#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
HVA_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd -P)"

usage() {
  cat <<EOF
Usage:
  ./healthcheck.sh [--tail LINES] [--since DURATION] [--debug-cache]

Summarizes the running llama.cpp server and recent Docker logs without dumping
the full log stream.

By default this is strict for HVA's cache goal: erased invalidated checkpoints
are BAD. Use --debug-cache when intentionally switching projects/sessions and
you want the cache details without a failing exit.
EOF
}

TAIL_LINES=3000
SINCE_ARG=""
CACHE_DEBUG=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tail)
      if [[ $# -lt 2 ]]; then
        echo "--tail requires a number" >&2
        exit 1
      fi
      TAIL_LINES="$2"
      shift 2
      ;;
    --since)
      if [[ $# -lt 2 ]]; then
        echo "--since requires a Docker duration or timestamp" >&2
        exit 1
      fi
      SINCE_ARG="$2"
      shift 2
      ;;
    --debug-cache)
      CACHE_DEBUG=1
      shift
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
done

case "$TAIL_LINES" in
  ''|*[!0-9]*)
    echo "--tail must be a number: $TAIL_LINES" >&2
    exit 1
    ;;
esac

# shellcheck disable=SC1091
source "$HVA_ROOT/internals/load-config.sh"
env_validate_common
source "$HVA_ROOT/internals/docker.sh"

for tool in curl jq awk grep; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required" >&2
    exit 2
  fi
done

container_id="$("${DOCKER[@]}" ps -q --filter "name=^/$LLAMA_CONTAINER$")"
if [[ -z "$container_id" ]]; then
  echo "llama health: BAD"
  echo "container: $LLAMA_CONTAINER is not running"
  exit 2
fi

log_args=(--tail "$TAIL_LINES")
if [[ -n "$SINCE_ARG" ]]; then
  log_args+=(--since "$SINCE_ARG")
fi
logs="$("${DOCKER[@]}" logs "${log_args[@]}" "$LLAMA_CONTAINER" 2>&1 || true)"
inspect_json="$("${DOCKER[@]}" inspect "$LLAMA_CONTAINER" 2>/dev/null || echo '[]')"

count_re() {
  local pattern="$1"
  grep -Eic "$pattern" <<< "$logs" || true
}

last_re() {
  local pattern="$1"
  grep -Ei "$pattern" <<< "$logs" | tail -n 1 || true
}

print_section() {
  printf '\n%s\n' "$1"
}

container_status="$(jq -r '.[0].State.Status // "unknown"' <<< "$inspect_json")"
container_started="$(jq -r '.[0].State.StartedAt // "unknown"' <<< "$inspect_json")"
image="$(jq -r '.[0].Config.Image // "unknown"' <<< "$inspect_json")"

model_arg="$(jq -r '.[0].Args as $args | ($args | index("-m")) as $i | if $i == null then "unknown" else $args[$i + 1] end' <<< "$inspect_json")"
alias_arg="$(jq -r '.[0].Args as $args | ($args | index("--alias")) as $i | if $i == null then "unknown" else $args[$i + 1] end' <<< "$inspect_json")"
ctx_arg="$(jq -r '.[0].Args as $args | ($args | index("-c")) as $i | if $i == null then "unknown" else $args[$i + 1] end' <<< "$inspect_json")"
ncmoe_arg="$(jq -r '.[0].Args as $args | ($args | index("-ncmoe")) as $i | if $i == null then "unknown" else $args[$i + 1] end' <<< "$inspect_json")"
fit_arg="$(jq -r '.[0].Args as $args | ($args | index("--fit")) as $i | if $i == null then "unknown" else $args[$i + 1] end' <<< "$inspect_json")"
fitt_arg="$(jq -r '.[0].Args as $args | ($args | index("-fitt")) as $i | if $i == null then "off" else $args[$i + 1] end' <<< "$inspect_json")"
kv_unified_arg="$(jq -r '.[0].Args as $args | if ($args | index("--kv-unified")) == null then "missing" else "on" end' <<< "$inspect_json")"
reasoning_budget_arg="$(jq -r '.[0].Args as $args | ($args | index("--reasoning-budget")) as $i | if $i == null then "unknown" else $args[$i + 1] end' <<< "$inspect_json")"
temperature_arg="$(jq -r '.[0].Args as $args | ($args | index("--temperature")) as $i | if $i == null then "unknown" else $args[$i + 1] end' <<< "$inspect_json")"
top_p_arg="$(jq -r '.[0].Args as $args | ($args | index("--top-p")) as $i | if $i == null then "unknown" else $args[$i + 1] end' <<< "$inspect_json")"
top_k_arg="$(jq -r '.[0].Args as $args | ($args | index("--top-k")) as $i | if $i == null then "unknown" else $args[$i + 1] end' <<< "$inspect_json")"
min_p_arg="$(jq -r '.[0].Args as $args | ($args | index("--min-p")) as $i | if $i == null then "unknown" else $args[$i + 1] end' <<< "$inspect_json")"
checkpoint_every_arg="$(jq -r '.[0].Args as $args | ($args | index("--checkpoint-every-n-tokens")) as $i | if $i == null then "missing" else $args[$i + 1] end' <<< "$inspect_json")"
ctx_checkpoints_arg="$(jq -r '.[0].Args as $args | ($args | index("--ctx-checkpoints")) as $i | if $i == null then "missing" else $args[$i + 1] end' <<< "$inspect_json")"

api_status="ok"
api_model="unknown"
if api_response="$(curl -fsS --max-time 2 "http://127.0.0.1:$LLAMA_HOST_PORT/v1/models" 2>/dev/null)"; then
  api_model="$(jq -r '.data[0].id // "unknown"' <<< "$api_response" 2>/dev/null || echo "unknown")"
else
  api_status="unreachable"
fi

bad_count="$(count_re '(^|[^a-z])(error|failed|fatal|panic|abort|segmentation fault|out of memory|oom|cuda[^[:space:]]*.*(error|failed)|bad_alloc)([^a-z]|$)')"
budget_exhausted_count="$(count_re 'reasoning-budget: budget exhausted')"
truncated_count="$(count_re 'truncated = [1-9]')"
cache_evict_count="$(count_re 'cache size limit reached|removing oldest entry')"
prompt_save_count="$(count_re 'prompt_save|prompt cache update took')"
checkpoint_restored_count="$(count_re 'restored context checkpoint')"
checkpoint_created_count="$(count_re 'created context checkpoint')"
checkpoint_erased_count="$(count_re 'erased invalidated context checkpoint')"
checkpoint_check_count="$(count_re 'Checking checkpoint with')"
checkpoint_periodic_count="$(count_re '[0-9]+ tokens since last checkpoint')"
checkpoint_forced_full_count="$(count_re 'forcing full prompt re-processing due to lack of cache data')"
request_ok_count="$(count_re 'done request: .* 200')"

last_prompt_eval="$(last_re 'prompt eval time =')"
last_eval="$(last_re '^[[:space:]]*eval time =')"
last_total="$(last_re '^[[:space:]]*total time =')"
last_cache_state="$(last_re 'cache state:|prompt 0x[0-9a-f]+:|total state size')"
last_checkpoint="$(last_re 'created context checkpoint|restored context checkpoint|erased invalidated context checkpoint')"
last_budget="$(last_re 'reasoning-budget:')"

avg_eval_tps="$(
  awk '
    /^[[:space:]]*eval time =/ {
      match($0, /, *[0-9.]+ tokens per second/)
      if (RSTART) {
        value = substr($0, RSTART + 2, RLENGTH - 20)
        sum += value
        count += 1
      }
    }
    END {
      if (count == 0) print "NA";
      else printf "%.2f", sum / count;
    }
  ' <<< "$logs"
)"

avg_prompt_tps="$(
  awk '
    /prompt eval time =/ {
      match($0, /, *[0-9.]+ tokens per second/)
      if (RSTART) {
        value = substr($0, RSTART + 2, RLENGTH - 20)
        sum += value
        count += 1
      }
    }
    END {
      if (count == 0) print "NA";
      else printf "%.2f", sum / count;
    }
  ' <<< "$logs"
)"

gpu_summary="nvidia-smi unavailable"
if command -v nvidia-smi >/dev/null 2>&1; then
  gpu_summary="$(
    nvidia-smi --query-gpu=index,name,memory.used,memory.free,memory.total --format=csv,noheader,nounits 2>/dev/null \
      | awk -F, '
          {
            gsub(/^ +| +$/, "", $1)
            gsub(/^ +| +$/, "", $2)
            gsub(/^ +| +$/, "", $3)
            gsub(/^ +| +$/, "", $4)
            gsub(/^ +| +$/, "", $5)
            printf "gpu%s %s: used=%s MiB free=%s MiB total=%s MiB\n", $1, $2, $3, $4, $5
          }
        ' \
      || true
  )"
  [[ -z "$gpu_summary" ]] && gpu_summary="nvidia-smi returned no GPU rows"
fi

verdict="OK"
if (( bad_count > 0 )) || [[ "$api_status" != "ok" ]] || (( CACHE_DEBUG == 0 && checkpoint_erased_count > 0 )); then
  verdict="BAD"
elif (( truncated_count > 0 || cache_evict_count > 0 || budget_exhausted_count > 0 || checkpoint_forced_full_count > 0 )); then
  verdict="WARN"
fi

echo "llama health: $verdict"
echo "container: $LLAMA_CONTAINER ($container_status, started $container_started)"
echo "image: $image"
echo "api: http://127.0.0.1:$LLAMA_HOST_PORT/v1/models ($api_status, model $api_model)"
echo "model: $model_arg (alias $alias_arg)"
echo "flags: ctx=$ctx_arg fit=$fit_arg fitt=$fitt_arg ncmoe=$ncmoe_arg kv_unified=$kv_unified_arg reasoning_budget=$reasoning_budget_arg checkpoint_every=$checkpoint_every_arg ctx_checkpoints=$ctx_checkpoints_arg"
echo "sampling: temperature=$temperature_arg top_p=$top_p_arg top_k=$top_k_arg min_p=$min_p_arg"

print_section "gpu"
printf '%s\n' "$gpu_summary"

if [[ -n "$SINCE_ARG" ]]; then
  print_section "log summary (last $TAIL_LINES lines since $SINCE_ARG)"
else
  print_section "log summary (last $TAIL_LINES lines)"
fi
echo "requests_200=$request_ok_count bad=$bad_count truncated=$truncated_count budget_exhausted=$budget_exhausted_count"
echo "checkpoints: restored=$checkpoint_restored_count created=$checkpoint_created_count periodic=$checkpoint_periodic_count erased=$checkpoint_erased_count checks=$checkpoint_check_count forced_full_reprocess=$checkpoint_forced_full_count"
echo "cache: evictions=$cache_evict_count saves_or_updates=$prompt_save_count"
echo "speed: avg_prompt_eval_tps=$avg_prompt_tps avg_eval_tps=$avg_eval_tps"

print_section "latest signals"
[[ -n "$last_cache_state" ]] && echo "$last_cache_state"
[[ -n "$last_checkpoint" ]] && echo "$last_checkpoint"
[[ -n "$last_budget" ]] && echo "$last_budget"
[[ -n "$last_prompt_eval" ]] && echo "$last_prompt_eval"
[[ -n "$last_eval" ]] && echo "$last_eval"
[[ -n "$last_total" ]] && echo "$last_total"

notable="$(
  grep -Ei 'error|failed|fatal|panic|abort|out of memory|oom|cuda[^[:space:]]*.*(error|failed)|bad_alloc|truncated = [1-9]|budget exhausted|cache size limit reached|forcing full prompt re-processing|erased invalidated context checkpoint|prompt cache update took' <<< "$logs" \
    | tail -n 12 \
    || true
)"
if [[ -n "$notable" ]]; then
  print_section "notable lines"
  printf '%s\n' "$notable"
fi

if [[ "$verdict" == "BAD" ]]; then
  exit 2
elif [[ "$verdict" == "WARN" ]]; then
  exit 1
fi
