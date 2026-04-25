#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
MODE="${1:-help}"

source "$ROOT/docker/versions.env"

usage() {
  cat <<EOF
Usage:
  ./print-setup-instructions.sh docker
  ./print-setup-instructions.sh local
EOF
}

print_docker() {
  cat <<EOF
- Add $ROOT/scripts to PATH -
- Put a .gguf model in $ROOT/models/ -
- Run 'hva' from any project -

config/hva-conf.json is created automatically on first run.
LLAMA_MODEL is auto-detected when only one .gguf is present.
EOF
}

print_local() {
print_docker
  cat <<EOF

- Optional secrets file -
cp -n "$ROOT/config/hva-secrets.json.sample" "$ROOT/config/hva-secrets.json"

-- TOOLS --

npm install -g "$HVA_V_PI_CODING_AGENT_NPM_SPEC"

-- OPTIONAL DEV TOOLS --

- Run commands -
rustup component add rust-analyzer
npm install -g "typescript@$HVA_V_TYPESCRIPT_VERSION" "typescript-language-server@$HVA_V_TYPESCRIPT_LS_VERSION" "prettier@$HVA_V_PRETTIER_VERSION" "eslint@$HVA_V_ESLINT_VERSION" "tsx@$HVA_V_TSX_VERSION" "pyright@$HVA_V_PYRIGHT_VERSION" "vscode-langservers-extracted@$HVA_V_VSCODE_LANGSERVERS_VERSION" "yaml-language-server@$HVA_V_YAML_LS_VERSION" "bash-language-server@$HVA_V_BASH_LS_VERSION" "dockerfile-language-server-nodejs@$HVA_V_DOCKERFILE_LS_VERSION"
go install "golang.org/x/tools/gopls@$HVA_V_GOPLS_VERSION"
dotnet tool install --global csharp-ls --version "$HVA_V_CSHARP_LS_VERSION"  # optional: only if you want C# tools on host

- Clangd run either: pacman -S clang / apt install clangd / brew install llvm -

-- RUN --

- Run commands -
export PI_CODING_AGENT_DIR="$PI_DIR"   # optional
hva --local
EOF
}

case "$MODE" in
  docker)
    print_docker
    ;;
  local|native)
    print_local
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    usage >&2
    exit 1
    ;;
esac
