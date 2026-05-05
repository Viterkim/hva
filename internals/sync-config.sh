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

merge_csv_pair() {
  local enabled_key="$1"
  local disabled_key="$2"
  local tmp_path="$3"
  local merged_path

  merged_path="$(mktemp "${TARGET}.XXXXXX")"
  jq -S \
    --arg enabled_key "$enabled_key" \
    --arg disabled_key "$disabled_key" \
    --slurpfile sample "$SAMPLE" '
      def csv($value):
        ($value // "")
        | split(",")
        | map(gsub("^\\s+|\\s+$"; ""))
        | map(select(. != ""));

      . as $target
      | (csv($target[$enabled_key])) as $target_enabled
      | (csv($target[$disabled_key])) as $target_disabled
      | (csv($sample[0][$enabled_key]) + csv($sample[0][$disabled_key])) as $sample_all
      | ($target_enabled + $target_disabled) as $target_all
      | ($sample_all | map(select(. as $entry | $target_all | index($entry) | not))) as $missing
      | .[$enabled_key] = (($target_enabled + $missing) | join(","))
      | .[$disabled_key] = ($target_disabled | join(","))
    ' "$tmp_path" > "$merged_path"
  mv "$merged_path" "$tmp_path"
}

merge_inject_csv() {
  local tmp_path="$1"
  local merged_path

  merged_path="$(mktemp "${TARGET}.XXXXXX")"
  jq -S --slurpfile sample "$SAMPLE" '
    def csv($value):
      ($value // "")
      | split(",")
      | map(gsub("^\\s+|\\s+$"; ""))
      | map(select(. != ""));

    . as $target
    | (csv($target.HVA_SOFT_INJECT_SKILLS)) as $target_soft
    | (csv($target.HVA_HARD_INJECT_SKILLS)) as $target_hard
    | (csv($target.HVA_DONT_INJECT_SKILLS)) as $target_dont
    | (csv($sample[0].HVA_SOFT_INJECT_SKILLS) + csv($sample[0].HVA_HARD_INJECT_SKILLS) + csv($sample[0].HVA_DONT_INJECT_SKILLS)) as $sample_all
    | ($target_soft + $target_hard + $target_dont) as $target_all
    | ($sample_all | map(select(. as $entry | $target_all | index($entry) | not))) as $missing
    | .HVA_SOFT_INJECT_SKILLS = ($target_soft | join(","))
    | .HVA_HARD_INJECT_SKILLS = ($target_hard | join(","))
    | .HVA_DONT_INJECT_SKILLS = (($target_dont + $missing) | join(","))
  ' "$tmp_path" > "$merged_path"
  mv "$merged_path" "$tmp_path"
}

migrate_config() {
  local tmp_path="$1"
  local migrated_path
  local old_default_inject="bash-style,documentation,js-ts-style,python-style,review,git-review,rust-style"

  migrated_path="$(mktemp "${TARGET}.XXXXXX")"
  jq -S --arg old_default_inject "$old_default_inject" '
    def csv($value):
      ($value // "")
      | split(",")
      | map(gsub("^\\s+|\\s+$"; ""))
      | map(select(. != ""));

    def join_csv($items): $items | join(",");

    def only($items; $allowed):
      $items | map(select(. as $entry | $allowed | index($entry)));

    ["bash-style","code","documentation","git-review","js-ts-style","python-style","review","rust-style"] as $auto_skills
    | ["grill-with-docs","hva-meta-code-review","hva-new-skill","improve-codebase-architecture","planner","read-repo","tdd","to-issues","to-prd","type-design"] as $manual_skills
    | if has("HVA_SKILLS_ENABLED") or has("HVA_SKILLS_DISABLED") then
        (csv(.HVA_SKILLS_ENABLED)) as $old_enabled
        | (csv(.HVA_SKILLS_DISABLED)) as $old_disabled
        | .HVA_AUTO_SKILLS_ENABLED = join_csv(only($old_enabled; $auto_skills))
        | .HVA_AUTO_SKILLS_DISABLED = join_csv(only($old_disabled; $auto_skills))
        | .HVA_MANUAL_SKILLS_ENABLED = join_csv(only($old_enabled; $manual_skills))
        | .HVA_MANUAL_SKILLS_DISABLED = join_csv(only($old_disabled; $manual_skills))
        | del(.HVA_SKILLS_ENABLED, .HVA_SKILLS_DISABLED)
      else
        .
      end
    |
    if has("HVA_SKIP_INJECT") then
      .HVA_SKIP_ALL_INJECTS = (.HVA_SKIP_INJECT // .HVA_SKIP_ALL_INJECTS)
      | del(.HVA_SKIP_INJECT)
    else
      .
    end
    | if (.HVA_SOFT_INJECT_SKILLS == $old_default_inject and (.HVA_HARD_INJECT_SKILLS // "") == "") then
        .HVA_SOFT_INJECT_SKILLS = ""
        | .HVA_DONT_INJECT_SKILLS = $old_default_inject
      else
        .
      end
  ' "$tmp_path" > "$migrated_path"
  mv "$migrated_path" "$tmp_path"
}

if [[ -f "$TARGET" ]]; then
  tmp="$(mktemp "${TARGET}.XXXXXX")"
  jq -S -s '.[0] * .[1]' "$SAMPLE" "$TARGET" > "$tmp"
  merge_csv_pair HVA_MCP_ENABLED HVA_MCP_DISABLED "$tmp"
  merge_csv_pair HVA_EXTENSIONS_ENABLED HVA_EXTENSIONS_DISABLED "$tmp"
  merge_csv_pair HVA_AUTO_SKILLS_ENABLED HVA_AUTO_SKILLS_DISABLED "$tmp"
  merge_csv_pair HVA_MANUAL_SKILLS_ENABLED HVA_MANUAL_SKILLS_DISABLED "$tmp"
  migrate_config "$tmp"
  merge_csv_pair HVA_AUTO_SKILLS_ENABLED HVA_AUTO_SKILLS_DISABLED "$tmp"
  merge_csv_pair HVA_MANUAL_SKILLS_ENABLED HVA_MANUAL_SKILLS_DISABLED "$tmp"
  merge_inject_csv "$tmp"
  unknown_keys="$(unknown_target_keys "$tmp")"
  new_keys="$(jq -r --slurpfile target "$TARGET" '
    ([keys_unsorted[]] - ($target[0] | keys_unsorted))[]?
  ' "$SAMPLE")"
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
  if [[ -n "$new_keys" ]]; then
    echo "inserted sample keys into config: $TARGET"
    while IFS= read -r key; do
      if [[ -n "$key" ]]; then
        val="$(jq -r --arg k "$key" '.[$k]' "$SAMPLE")"
        echo "  $key = $val"
      fi
    done <<< "$new_keys"
  elif (( QUIET == 0 )); then
    echo "updated config from sample: $TARGET"
  fi
  if [[ -n "$unknown_keys" ]]; then
    echo "updated config with missing sample keys: $TARGET" >&2
    echo "unknown keys in config: $TARGET" >&2
    while IFS= read -r key; do
      [[ -n "$key" ]] && echo "  $key" >&2
    done <<< "$unknown_keys"
    exit 1
  fi
  exit 0
fi

mkdir -p "$(dirname "$TARGET")"
install -m 0644 "$SAMPLE" "$TARGET"
echo "created config: $TARGET"
