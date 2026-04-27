# Docker reference

Docker is the default HVA path: llama.cpp runs in Docker and Pi runs inside the dev container.

The README is the quick-start page. This file is only the Docker-specific reference: config keys, one-shot env overrides, and the few behavior details that are easy to forget.

## What matters

- Host requirements: Linux shell, Docker, `curl`, `jq`, `awk`, `grep`, and coreutils
- GPU is optional: NVIDIA (CUDA), AMD (ROCm), Intel (Vulkan), or CPU-only all work
- Put `.gguf` files in `models/`
- `config/hva-conf.json` is created automatically on first `hva`, or explicitly with `./internals/sync-config.sh`
- `config/hva-secrets.json` is optional and should be created from `config/hva-secrets.json.sample`
- If exactly one `.gguf` exists, `LLAMA_MODEL` can stay empty and HVA auto-selects it

## Persistent config

All persistent settings live in `config/hva-conf.json`.

Model and container:

```text
LLAMA_MODELS
LLAMA_MODEL
LLAMA_MODEL_ALIAS
LLAMA_CONTAINER
LLAMA_IMAGE
LLAMA_GPU_VENDOR
LLAMA_HOST_PORT
LLAMA_NETWORK
```

Context and sampling:

```text
LLAMA_CONTEXT_SIZE
LLAMA_REASONING_BUDGET
LLAMA_NCMOE
LLAMA_AUTOFIT_TOKENS
LLAMA_ENABLE_THINKING
LLAMA_PRESERVE_THINKING
LLAMA_TEMPERATURE
LLAMA_TOP_P
LLAMA_TOP_K
LLAMA_MIN_P
LLAMA_PRESENCE_PENALTY
LLAMA_REPEAT_PENALTY
```

Tooling and mounts:

```text
HVA_MCP_ENABLED
HVA_MCP_DISABLED
SEARXNG_URL
HVA_LOAD_SECRETS
HVA_MOUNT_GIT
HVA_MOUNT_GITCONFIG
HVA_MOUNT_NVIM
HVA_MOUNT_SSH
HVA_MOUNT_DOCKER_SOCKET
HVA_UNSAFE
HVA_CSHARP
```

`HVA_CSHARP=true` only matters when building the dev image.

## One-shot host env overrides

These are host-side overrides for a single command. They do not persist.

```text
HVA_RESTART_LLAMA=1
HVA_REBUILD=1
HVA_SKIP_LLAMA=1
HVA_WAIT_LLAMA=0
HVA_ALLOW_SYSTEM_TMP_WORKSPACE=1
HVA_LLAMA_WAIT_TIMEOUT=120
HVA_LLAMA_LOG_TAIL=200
```

If you change llama-related config, restart it with:

```bash
HVA_RESTART_LLAMA=1 hva
```

After `hva --llama-cpp-update`, restart llama the same way so the new image is used.

## Docker-specific behavior

- HVA-owned runtime state lives under `.hva-state/`
- The target project does not get HVA state, AGENTS files, extensions, or skills written into it
- Pi sessions live under `.hva-state/workspaces/<workspace-hash>/pi-sessions/` and use Pi's built-in `--continue`
- Pi extension dependencies install into HVA `.hva-state/`, so normal Docker mode does not need host Node
- `HVA_MCP_*` and `SEARXNG_URL` are passed into the container explicitly. Missing passthrough fails fast
- Pi resource auto-discovery is disabled in Docker mode. HVA extensions, root skills, and injected runtime guidance are loaded explicitly
- When HVA can use a user-defined Docker network such as `LLAMA_NETWORK=hva-net`, the dev container talks to llama and SearXNG by container name on that shared network
- If Docker bridge networking is broken on the host, HVA falls back to host networking and caches the last working mode in `.hva-state/docker-network-mode`
- If `searxng` is enabled in `HVA_MCP_ENABLED`, HVA starts the helper automatically before Pi opens
- Visible Pi thinking is post-processed into a terse telegraph style before UI render/session persistence. This changes display/context carryover, not model-side reasoning token spend

Security-sensitive mount behavior is documented in `caveats.md`.

## Files

Tracked inputs:

```text
config/hva-conf.json.sample
config/hva-secrets.json.sample
docker/versions.env
pi/extensions/
hva-runtime/
skills/
pi/render-models.sh
pi/render-settings.sh
pi/tasks-template.md
```

Generated:

```text
config/hva-conf.json
config/hva-secrets.json
.hva-state/
```

Workspace-generated:

```text
tasks.md
```

## Troubleshooting

Model missing:

- Check `LLAMA_MODELS`
- Check `LLAMA_MODEL`
- Check that the `.gguf` file exists at the expected filename

Llama not ready:

```bash
hva --healthcheck --tail 8000
hva --llama-cpp-logs-full
```

GPU detection:

```bash
# NVIDIA
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
# AMD ROCm
rocm-smi
# Intel
clinfo | grep -i intel
```

`LLAMA_GPU_VENDOR` can be set explicitly to `nvidia`, `amd`, `intel`, `cpu`, or `none` to skip auto-detection.

`LLAMA_IMAGE` overrides the auto-selected backend image.

Port conflict:

```bash
HVA_RESTART_LLAMA=1 hva
```
