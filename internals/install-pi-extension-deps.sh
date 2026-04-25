#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd -P)"
EXT_DIR="$ROOT/pi/extensions"

if [[ ! -f "$EXT_DIR/package.json" ]]; then
  echo "pi extension package manifest missing: $EXT_DIR/package.json" >&2
  exit 1
fi

need_install=0

if [[ ! -d "$EXT_DIR/node_modules" ]]; then
  need_install=1
fi

if [[ ! -f "$EXT_DIR/package-lock.json" ]]; then
  need_install=1
fi

if [[ "$EXT_DIR/package.json" -nt "$EXT_DIR/package-lock.json" ]]; then
  need_install=1
fi

if (( need_install == 0 )) && ! npm ls --prefix "$EXT_DIR" >/dev/null 2>&1; then
  need_install=1
fi

if (( need_install == 1 )); then
  echo "installing Pi extension deps..."
  npm ci --prefix "$EXT_DIR" --omit=dev
fi
