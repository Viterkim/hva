# Docker Setup

Default path. Llama runs in Docker. Nanocoder runs inside dev container.

## requirements

- Linux shell
- Docker usable by user, or via `sudo docker`
- NVIDIA GPU with Docker GPU runtime
- `curl`
- GGUF model file

`hva --healthcheck` also needs `jq`, `awk`, `grep`.

## setup

```bash
cd /path/to/hva && mkdir -p models && ./internals/sync-env-source.sh
```

Put `.gguf` files in `models/`. Edit `LLAMA_MODEL` in `env/env-source.sh`, or
leave it empty when exactly one `.gguf` exists. Do not source `env/env-source.sh`.

After pulls that add new env vars, rerun:

```bash
./internals/sync-env-source.sh
```

Add `scripts/` to PATH. Optional secrets:

```bash
mkdir -p ~/.config/nanocoder
cp -n nanocoder/mcp.env.example ~/.config/nanocoder/mcp.env
$EDITOR ~/.config/nanocoder/mcp.env
```

Secret envs passed when set:

```text
BRAVE_API_KEY                  when brave-search is in HVA_MCP_ENABLED
GITHUB_PERSONAL_ACCESS_TOKEN   when github or rust-docs is in HVA_MCP_ENABLED
GITHUB_TOKEN               alias for GITHUB_PERSONAL_ACCESS_TOKEN (either works)
HF_TOKEN
HUGGING_FACE_HUB_TOKEN
```

## run

```bash
hva
```

It starts/reuses llama, builds dev image if missing, stops with a clear message when
the dev image is stale, manages `AGENTS.md` when possible, opens Nanocoder, then drops
to shell after exit.

Docker mode runs Nanocoder in yolo mode and trusts container/workspace paths by
default. Expect no approval prompts inside the dev container.

Some MCP helpers install on first run through `npx -y` or `uvx`. First run needs
network. Optional logs land in `.nanocoder/output/` inside each workspace when
enabled:

```text
.nanocoder/output/nanocoder.txt
.nanocoder/output/tools/*.log
```

## commands

- `hva`: Nanocoder in container
- `hva --bash`: container shell, no llama wait
- `hva --msg "text"`: one-shot Nanocoder message
- `hva --prompt "text"`: one-shot Nanocoder message (alias for --msg)
- `hva --prompt-file /path/to/prompt.txt`: one-shot Nanocoder run from file
- `hva --stop`: stop llama server and searxng
- `hva --start-searxng`: start SearXNG web search container
- `hva --stop-searxng`: stop SearXNG container only
- `hva --loop`: run root `tasks.md` inside one long-lived dev container
- `hva --loop-init`: create a root `tasks.md` template
- `hva --loop-stop`: request stop after the current loop iteration
- `hva --loop-status`: print current loop state
- `hva --update`: pull latest hva, sync env vars, auto-refresh managed config
- `hva --reset-nanocoder-cache`: clear cached nanocoder config (rebuilt on next run)
- `hva --daemon`: start llama server as background daemon
- `hva --diff-review REV`: review `REV..HEAD`
- `hva --diff-review-branch BRANCH`: review `merge-base(BRANCH, HEAD)..HEAD`
- `hva --diff-review-main`: review `merge-base(main/master, HEAD)..HEAD`
- `hva --diff-review-staged`: review staged diff
- `hva --diff-review-unstaged`: review unstaged diff
- `hva --diff-review-all`: review tracked + untracked changes
- `hva --healthcheck`: compact llama health
- `hva --llama-cpp-update`: update pinned llama.cpp image digest in `docker/versions.env`, then pull it
- `hva --llama-cpp-logs-full`: print full llama server container logs
- `hva --build-docker-prison`: build dev image if missing/outdated (`--force` to rebuild anyway)
- `hva --check-versions`: check pinned vs latest upstream versions
- `benchmarking/benchmarking.sh`: benchmark all `.gguf` files (early WIP)

## env

Set in `env/env-source.sh`:

```text
LLAMA_MODELS
LLAMA_MODEL
LLAMA_MODEL_ALIAS
LLAMA_CONTAINER
LLAMA_HOST_PORT
LLAMA_CONTEXT_SIZE
LLAMA_REASONING_BUDGET
LLAMA_NCMOE
LLAMA_AUTOFIT_TOKENS   nonzero=use autofit target tokens; empty/0=use LLAMA_NCMOE
LLAMA_ENABLE_THINKING
LLAMA_PRESERVE_THINKING
LLAMA_TEMPERATURE
LLAMA_TOP_P
LLAMA_TOP_K
LLAMA_MIN_P
LLAMA_PRESENCE_PENALTY
LLAMA_REPEAT_PENALTY
HVA_V_NANOCODER_SPEC    Docker Nanocoder spec: npm package, git spec, or GitHub commit ref
HVA_V_NANOCODER_NPM_SPEC Native Nanocoder npm release spec
HVA_MCP_ENABLED
HVA_MCP_DISABLED
HVA_LSP_ENABLED
HVA_LSP_DISABLED
HVA_MANAGE_AGENTS       1=manage AGENTS.md symlink/template in workspaces (default 1)
HVA_COPY_AGENTS         legacy alias for HVA_MANAGE_AGENTS
HVA_LOAD_MCP_ENV        1=load ~/.config/nanocoder/mcp.env (default 1)
HVA_MOUNT_GITCONFIG     1=mount ~/.gitconfig into container (default 0)
HVA_MOUNT_NVIM          1=mount ~/.config/nvim into container (default 0)
HVA_MOUNT_SSH           1=mount ~/.ssh into container (default 0)
HVA_LOG_NANOCODER_OUTPUT 1=write Nanocoder internal logs to workspace .nanocoder/output (default 0)
HVA_LOG_TOOL_OUTPUT     1=write MCP stderr logs to workspace .nanocoder/output/tools (default 0)
HVA_UNSAFE              1=SYS_PTRACE, seccomp=unconfined, docker socket (default 0)
```

```text
SEARXNG_URL                URL for self-hosted SearXNG (default: http://host.docker.internal:8888)
SEARXNG_HOST_PORT          host port for SearXNG container (default: 8888)
```

One-run overrides:

```text
HVA_RESTART_LLAMA=1
HVA_REBUILD=1
HVA_SKIP_LLAMA=1
HVA_WAIT_LLAMA=0
LLAMA_AUTOFIT_TOKENS=0
HVA_MANAGE_AGENTS=0
HVA_MOUNT_GITCONFIG=1
HVA_MOUNT_NVIM=1
HVA_INIT_WORKSPACE=1
HVA_MOUNT_SSH=1
HVA_LOAD_MCP_ENV=0
HVA_LOG_NANOCODER_OUTPUT=1
HVA_LOG_TOOL_OUTPUT=1
HVA_UNSAFE=1               # SYS_PTRACE, seccomp=unconfined, docker socket (debuggers, docker-in-docker)
HVA_ALLOW_SYSTEM_TMP_WORKSPACE=1
HVA_LLAMA_WAIT_TIMEOUT=120
HVA_LLAMA_LOG_TAIL=200
```

Build flags (set in `env/env-source.sh`, applied on next `hva --build-docker-prison`):

```text
HVA_CSHARP=true            # include C# LSP (csharp-ls + dotnet); default false
```

Use `HVA_RESTART_LLAMA=1 hva` after llama flag/env
changes. Running llama container keeps old flags.

After `hva --llama-cpp-update`, restart llama to use new image:

```bash
HVA_RESTART_LLAMA=1 hva
```

## loop tasks file

`hva --loop` always uses `tasks.md` in the workspace root. Create it with:

```bash
hva --loop-init
```

`tasks.md` may start with YAML front matter:

```yaml
---
loop_hours: 8
loop_minutes: 0
loop_max_iterations: 0
loop_review: true
loop_improve: true
---
```

After that, use normal markdown. Best results come from checkbox tasks, but
loose bullets and numbered steps are also accepted and normalized on the first
pass. When the time limit runs out, the current iteration finishes first and
the loop stops before the next one starts.

## files

Tracked shared config:

```text
nanocoder/.mcp.json
nanocoder/bin/
nanocoder/AGENT-example.md
nanocoder/nanocoder-preferences.sample.json
nanocoder/mcp.env.example
nanocoder/tasks-template.md
nanocoder/render-mcp-config.sh
nanocoder/render-agents-config.sh
nanocoder/render-lsp-mask.sh
docker/versions.env
```

Private/generated:

```text
env/env-source.sh
nanocoder/agents.config.json
nanocoder/nanocoder-preferences.json
.hva-state/
~/.config/nanocoder/mcp.env
```

Workspace-generated:

```text
AGENTS.md               managed symlink when absent or when migrating old hva copy
AGENTS.local.md         optional local additions appended to the managed template
tasks.md                loop queue file created by hva --loop-init
```

## troubleshoot

Model missing: check `LLAMA_MODELS`, `LLAMA_MODEL`, filename.

Llama not ready:

```bash
hva --healthcheck --tail 8000
hva --llama-cpp-logs-full
```

GPU:

```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

Port conflict: change `LLAMA_HOST_PORT`, then:

```bash
HVA_RESTART_LLAMA=1 hva
```
