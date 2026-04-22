# Native Nanocoder

Use this only when you want host Nanocoder instead of container Nanocoder.
Llama still runs through Docker.

## setup

Do docker setup first, then print native config commands:

```bash
./print-setup-instructions.sh local
```

If a pull adds new env vars to `env/env-source-sample.sh`, sync your gitignored
`env/env-source.sh` explicitly:

```bash
./internals/sync-env-source.sh
```

Run printed commands. `./internals/overwrite-local-confs.sh` symlinks helper binaries into `~/.config/nanocoder/bin`,
render `~/.config/nanocoder/.mcp.json`, render repo-local `nanocoder/agents.config.json`,
seed repo-local `nanocoder/nanocoder-preferences.json` when missing, and symlink those
repo-local gitignored files into `~/.config/nanocoder/`.

Rerun after changing `HVA_MCP_ENABLED`, `HVA_MCP_DISABLED`, `HVA_LSP_ENABLED`,
`HVA_LSP_DISABLED`, `LLAMA_HOST_PORT`, `LLAMA_MODEL_ALIAS`, or `~/.config/nanocoder/mcp.env`:

```bash
./internals/overwrite-local-confs.sh
```

Dry-run setup smoke without touching real config:

```bash
NANOCODER_CONFIG_DIR="$(mktemp -d)" ./internals/overwrite-local-confs.sh
```

## tools

`./print-setup-instructions.sh local` prints pinned install commands from
`docker/versions.env`. Native Nanocoder uses the pinned npm release; Docker may
use a newer GitHub commit. Install `clangd` through system package manager.

Some MCP helpers install on first run through `npx -y` or `uvx`. Native mode needs
network then. MCP stderr logs go to `/dev/null` unless `HVA_LOG_TOOL_OUTPUT=1`.

## run

```bash
hva --daemon
export PATH="$HOME/.config/nanocoder/bin/lsp-mask:$PATH"
nanocoder
```

Stop: `hva --stop`.

Keep `~/.config/nanocoder/mcp.env`, history, and any logs private. Keep repo-local
`nanocoder/agents.config.json` and `nanocoder/nanocoder-preferences.json` untracked.
