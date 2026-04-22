#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
VERSIONS_FILE="${SCRIPT_DIR}/../docker/versions.env"

# shellcheck source=../docker/versions.env
source "$VERSIONS_FILE"

DOCKER=()
if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
    DOCKER=(sudo docker)
fi

# ---- fetch helpers ----

fetch_npm() {
    local pkg="$1"
    local encoded
    encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],''))" "$pkg")
    curl -sf "https://registry.npmjs.org/${encoded}/latest" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','?'))" 2>/dev/null || echo "?"
}

fetch_go() {
    local mod="$1"
    local encoded
    encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],''))" "$mod")
    curl -sf "https://proxy.golang.org/${encoded}/@latest" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('Version','?'))" 2>/dev/null || echo "?"
}

fetch_crate() {
    local crate="$1"
    curl -sf -A "hva-version-checker/1.0" "https://crates.io/api/v1/crates/${crate}" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('crate',{}).get('max_stable_version','?'))" 2>/dev/null || echo "?"
}

fetch_pypi() {
    local pkg="$1"
    curl -sf "https://pypi.org/pypi/${pkg}/json" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('info',{}).get('version','?'))" 2>/dev/null || echo "?"
}

fetch_nuget() {
    local pkg="${1,,}"
    curl -sf "https://api.nuget.org/v3-flatcontainer/${pkg}/index.json" \
        | python3 -c "import sys,json; vs=json.load(sys.stdin).get('versions',[]); stable=[v for v in vs if '-' not in v]; print(stable[-1] if stable else '?')" 2>/dev/null || echo "?"
}

fetch_github_release() {
    local repo="$1"
    curl -sf "https://api.github.com/repos/${repo}/releases/latest" \
        | python3 -c "import sys,json; t=json.load(sys.stdin).get('tag_name','?'); print(t.lstrip('v'))" 2>/dev/null || echo "?"
}

fetch_container_digest() {
    local image_ref="$1"
    local tag_ref="${image_ref%@*}"

    if (( ${#DOCKER[@]} == 0 )); then
        echo "?"
        return
    fi

    "${DOCKER[@]}" buildx imagetools inspect "$tag_ref" 2>/dev/null \
        | awk '/^Digest:/ { print $2; exit }' \
        || echo "?"
}

fetch_rust_stable() {
    curl -sf "https://static.rust-lang.org/dist/channel-rust-stable.toml" \
        | awk '
            /^\[pkg\.rust\]$/ { in_rust = 1; next }
            in_rust && /^\[/ { in_rust = 0 }
            in_rust && /^version = "/ {
                if (!found && match($0, /"[0-9]+\.[0-9]+\.[0-9]+/)) {
                    print substr($0, RSTART + 1, RLENGTH - 1)
                    found = 1
                }
            }
            END {
                if (!found) print "?"
            }
        ' 2>/dev/null || echo "?"
}

fetch_node_lts() {
    curl -sf "https://nodejs.org/dist/index.json" \
        | python3 -c "import sys,json; print(next((r['version'].lstrip('v') for r in json.load(sys.stdin) if r.get('lts')),'?'))" 2>/dev/null || echo "?"
}

fetch_dotnet_channel() {
    curl -sf "https://raw.githubusercontent.com/dotnet/core/main/release-notes/releases-index.json" \
        | python3 -c "
import sys, json
d = json.load(sys.stdin)
channels = [
    r['channel-version'] for r in d.get('releases-index', [])
    if r.get('support-phase') in ('active', 'lts', 'maintenance')
    and r.get('release-type') != 'preview'
    and '-' not in r['channel-version']
]
print(sorted(channels, key=lambda v: [int(x) for x in v.split('.')])[-1] if channels else '?')
" 2>/dev/null || echo "?"
}

# ---- output ----

GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
NC=$'\033[0m'

check() {
    local name="$1" pinned="$2" latest="$3"
    local p="${pinned#v}" l="${latest#v}"
    local status
    if   [[ "$latest" == "?" ]]; then status="?"
    elif [[ "$p" == "$l"    ]]; then status="${GREEN}ok${NC}"
    else                              status="${RED}update${NC}"
    fi
    printf "  %-40s %-18s %-18s %b\n" "$name" "$pinned" "$latest" "$status"
}

check_image() {
    local name="$1" pinned_ref="$2" latest_digest="$3"
    local pinned_digest="${pinned_ref##*@}"
    local pinned_short="${pinned_digest:0:18}"
    local latest_short="$latest_digest"
    local status

    if [[ "$latest_digest" == "?" ]]; then
        status="?"
    else
        latest_short="${latest_digest:0:18}"
        if [[ "$pinned_digest" == "$latest_digest" ]]; then
            status="${GREEN}ok${NC}"
        else
            status="${RED}update${NC}"
        fi
    fi

    printf "  %-40s %-18s %-18s %b\n" "$name" "$pinned_short" "$latest_short" "$status"
}

check_custom() {
    local name="$1" pinned="$2"
    printf "  %-40s %-18s %-18s %b\n" "$name" "$pinned" "custom" "${GREEN}ok${NC}"
}

printf "\n  %-40s %-18s %-18s\n" "package" "pinned" "latest"
printf "  %-40s %-18s %-18s\n"   "-------" "------" "------"

echo ""
echo "  images"
check_image "ubuntu base image" "$HVA_V_UBUNTU_BASE_IMAGE" "$(fetch_container_digest "$HVA_V_UBUNTU_BASE_IMAGE")"
check_image "llama.cpp server image" "$HVA_V_LLAMA_CPP_IMAGE" "$(fetch_container_digest "$HVA_V_LLAMA_CPP_IMAGE")"
check_image "github-mcp-server image" "$HVA_V_GITHUB_MCP_SERVER_IMAGE" "$(fetch_container_digest "$HVA_V_GITHUB_MCP_SERVER_IMAGE")"
check_image "searxng image"           "$HVA_V_SEARXNG_IMAGE"           "$(fetch_container_digest "$HVA_V_SEARXNG_IMAGE")"

echo ""
echo "  runtimes"
check "rust"             "$HVA_V_RUST_VERSION"   "$(fetch_rust_stable)"
check "node (lts)"       "$HVA_V_NODE_VERSION"   "$(fetch_node_lts)"
check "uv"               "$HVA_V_UV_VERSION"     "$(fetch_github_release astral-sh/uv)"
check "dotnet (channel)" "$HVA_V_DOTNET_CHANNEL" "$(fetch_dotnet_channel)"

echo ""
echo "  npm"
check "nanocoder npm" "${HVA_V_NANOCODER_NPM_SPEC#@nanocollective/nanocoder@}" "$(fetch_npm @nanocollective/nanocoder)"
check_custom "nanocoder docker spec" "$HVA_V_NANOCODER_SPEC"
check "typescript"                   "$HVA_V_TYPESCRIPT_VERSION"         "$(fetch_npm typescript)"
check "typescript-language-server"   "$HVA_V_TYPESCRIPT_LS_VERSION"      "$(fetch_npm typescript-language-server)"
check "prettier"                     "$HVA_V_PRETTIER_VERSION"           "$(fetch_npm prettier)"
check "eslint"                       "$HVA_V_ESLINT_VERSION"             "$(fetch_npm eslint)"
check "tsx"                          "$HVA_V_TSX_VERSION"                "$(fetch_npm tsx)"
check "pyright"                      "$HVA_V_PYRIGHT_VERSION"            "$(fetch_npm pyright)"
check "vscode-langservers-extracted" "$HVA_V_VSCODE_LANGSERVERS_VERSION" "$(fetch_npm vscode-langservers-extracted)"
check "yaml-language-server"         "$HVA_V_YAML_LS_VERSION"            "$(fetch_npm yaml-language-server)"
check "bash-language-server"         "$HVA_V_BASH_LS_VERSION"            "$(fetch_npm bash-language-server)"
check "dockerfile-language-server"   "$HVA_V_DOCKERFILE_LS_VERSION"      "$(fetch_npm dockerfile-language-server-nodejs)"
check "brave-search-mcp-server"      "$HVA_V_BRAVE_SEARCH_MCP_VERSION"   "$(fetch_npm @brave/brave-search-mcp-server)"
check "mcp-ripgrep"                  "$HVA_V_MCP_RIPGREP_VERSION"        "$(fetch_npm mcp-ripgrep)"
check "npm-search-mcp-server"        "$HVA_V_NPM_SEARCH_MCP_VERSION"     "$(fetch_npm npm-search-mcp-server)"
check "mcp-searxng"              "$HVA_V_SEARXNG_MCP_VERSION"        "$(fetch_npm mcp-searxng)"

echo ""
echo "  go"
check "gopls"       "$HVA_V_GOPLS_VERSION"       "$(fetch_go golang.org/x/tools/gopls)"
check "staticcheck" "$HVA_V_STATICCHECK_VERSION" "$(fetch_go honnef.co/go/tools)"
check "gofumpt"     "$HVA_V_GOFUMPT_VERSION"     "$(fetch_go mvdan.cc/gofumpt)"
check "dlv"         "$HVA_V_DLV_VERSION"         "$(fetch_go github.com/go-delve/delve)"
check "lazydocker"  "$HVA_V_LAZYDOCKER_VERSION"  "$(fetch_go github.com/jesseduffield/lazydocker)"

echo ""
echo "  cargo"
check "rust-docs-mcp"  "$HVA_V_RUST_DOCS_MCP_VERSION"  "$(fetch_crate rust-docs-mcp)"
check "cargo-binstall" "$HVA_V_CARGO_BINSTALL_VERSION"  "$(fetch_crate cargo-binstall)"
check "just"           "$HVA_V_JUST_VERSION"            "$(fetch_crate just)"
check "cargo-nextest"  "$HVA_V_NEXTEST_VERSION"         "$(fetch_crate cargo-nextest)"
check "bottom"         "$HVA_V_BOTTOM_VERSION"          "$(fetch_crate bottom)"

echo ""
echo "  python (uv)"
check "ruff"    "$HVA_V_RUFF_VERSION"    "$(fetch_pypi ruff)"
check "mypy"    "$HVA_V_MYPY_VERSION"    "$(fetch_pypi mypy)"
check "pytest"  "$HVA_V_PYTEST_VERSION"  "$(fetch_pypi pytest)"
check "ipython" "$HVA_V_IPYTHON_VERSION" "$(fetch_pypi ipython)"
check "mcp-pypi" "$HVA_V_MCP_PYPI_VERSION" "$(fetch_pypi mcp-pypi)"

echo ""
echo "  dotnet"
check "csharp-ls" "$HVA_V_CSHARP_LS_VERSION" "$(fetch_nuget csharp-ls)"
echo ""
