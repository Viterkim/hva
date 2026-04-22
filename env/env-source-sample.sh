#!/usr/bin/env bash

LLAMA_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LLAMA_ENV_ROOT="$(cd "$LLAMA_ENV_DIR/.." && pwd -P)"

# model
export LLAMA_MODELS="$LLAMA_ENV_ROOT/models"
export LLAMA_MODEL=""  # leave empty to auto-detect the single .gguf in models/
export LLAMA_CONTEXT_SIZE="262144"

# mcp — available: github,ripgrep,rust-docs,pypi,npm-search,brave-search,searxng
# every server must appear in exactly one list
export HVA_MCP_ENABLED="rust-docs,ripgrep,searxng"
export HVA_MCP_DISABLED="github,pypi,npm-search,brave-search"

# web search — start with: hva --start-searxng  stop with: hva --stop
export SEARXNG_URL="http://host.docker.internal:8888"

# lsp — available: rust,typescript,python,json,html,css,yaml,bash,docker,go,clangd,csharp
# csharp also needs HVA_CSHARP=true and a rebuild
export HVA_LSP_ENABLED="rust,typescript,python,json,html,css,yaml,bash,docker,go,clangd"
export HVA_LSP_DISABLED="csharp"

# logging — output goes to .nanocoder/output/ (gitignored)
export HVA_LOG_NANOCODER_OUTPUT="0"
export HVA_LOG_TOOL_OUTPUT="0"

# advanced
export LLAMA_MODEL_ALIAS="local"
export LLAMA_CONTAINER="hva-llama-server"
export LLAMA_HOST_PORT="8080"
export LLAMA_REASONING_BUDGET="-1"
export LLAMA_NCMOE="11"
export LLAMA_AUTOFIT_TOKENS="1024"  # 0 = use LLAMA_NCMOE instead

export HVA_COPY_AGENTS="${HVA_COPY_AGENTS:-1}"
export HVA_LOAD_MCP_ENV="${HVA_LOAD_MCP_ENV:-1}"
export HVA_MOUNT_GITCONFIG="${HVA_MOUNT_GITCONFIG:-0}"
export HVA_MOUNT_NVIM="${HVA_MOUNT_NVIM:-0}"
export HVA_MOUNT_SSH="${HVA_MOUNT_SSH:-0}"
export HVA_UNSAFE="${HVA_UNSAFE:-0}"      # see caveats.md
export HVA_CSHARP="${HVA_CSHARP:-false}"  # rebuild required: hva --build-docker-prison

