# Docker reference

README is the main page.

This file only keeps the Docker-specific bits that are still worth remembering.

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
HVA_SKILLS_ENABLED
HVA_SKILLS_DISABLED
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

These only affect one command run.

```text
HVA_RESTART_LLAMA=1
HVA_REBUILD=1
HVA_SKIP_LLAMA=1
HVA_WAIT_LLAMA=0
HVA_ALLOW_SYSTEM_TMP_WORKSPACE=1
HVA_LLAMA_WAIT_TIMEOUT=120
HVA_LLAMA_LOG_TAIL=200
```

If you change llama-side config, restart llama with:

```bash
HVA_RESTART_LLAMA=1 hva
```

## Docker notes

- HVA state lives under `.hva-state/`
- The target repo stays clean. HVA does not write agent files, skills, or extensions into it
- Pi sessions live under `.hva-state/workspaces/<workspace-hash>/pi-sessions/`
- HVA loads its own extensions, skills, and runtime guidance explicitly
- When `LLAMA_NETWORK` works, the dev container talks to llama and SearXNG by container name on that shared network
- If bridge networking is broken, HVA falls back to host mode and remembers that in `.hva-state/docker-network-mode`
- Use `hva --new-hard` after changing dev-container mounts, env passthrough, helper mounts, or startup wiring

Security-sensitive mounts are documented in `caveats.md`.

## Troubleshooting

Llama not ready:

```bash
hva --healthcheck --tail 8000
hva --llama-cpp-logs-full
```

If the wrong model or backend is starting:

- check `LLAMA_MODEL`
- check `LLAMA_IMAGE`
- check `LLAMA_GPU_VENDOR`
