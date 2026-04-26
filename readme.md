# Hva'? (hva) - Local LLM Vibe Coding Setup - Using 'Pi Coding Agent' + 'llama.cpp'

- Local llama.cpp server (runs the LLM) [Github Link](https://github.com/ggml-org/llama.cpp)
- Pi coding agent in dev container (yolo mode in a container with no git) [Github Link](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent)

## Quick start

1. Add `scripts/` to your PATH
2. Download a `.gguf` model and put it in `models/`
3. Run `hva`

`config/hva-conf.json` is created automatically on first run.

### Recommended models (Entire model does not have to be in VRAM)

- [i1-IQ3_S download (15.4 Gb)](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-Abliterix-EGA-abliterated-i1-GGUF/resolve/main/Qwen3.6-35B-A3B-Abliterix-EGA-abliterated.i1-IQ3_S.gguf)
- [i1-Q4_K_M download (21.3 Gb)](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-Abliterix-EGA-abliterated-i1-GGUF/resolve/main/Qwen3.6-35B-A3B-Abliterix-EGA-abliterated.i1-Q4_K_M.gguf)
- [i1-Q5_K_M download (24.8 Gb)](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-Abliterix-EGA-abliterated-i1-GGUF/resolve/main/Qwen3.6-35B-A3B-Abliterix-EGA-abliterated.i1-Q5_K_M.gguf)

- The model page: [Qwen3.6-35B-A3B-Abliterix-EGA-abliterated-i1-GGUF](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-Abliterix-EGA-abliterated-i1-GGUF)

## Shell Completion

**bash** — add to `~/.bashrc`:

```bash
source /path/to/hva/completions/hva.bash
```

**fish** — symlink into completions:

```fish
ln -s /path/to/hva/completions/hva.fish ~/.config/fish/completions/hva.fish
```

## Commands

```
hva                          open Pi session (resume or new)
hva --new                    fresh session
hva --bash                   shell in dev container
hva --msg "text"             one-shot message
hva --prompt-file FILE       one-shot from file
hva --diff-review-main       code review vs main (also: --diff-review-branch BRANCH, --diff-review-unstaged, --diff-review-staged, --diff-review-all, --diff-review SHA)
hva --daemon                 start llama server as background daemon
hva --stop                   stop llama, searxng, dev container
hva --start-searxng          start SearXNG
hva --stop-searxng           stop SearXNG
hva --healthcheck            llama health verdict
hva --llama-cpp-logs-full    full llama container logs
hva --build-docker-prison    build dev image (--force to rebuild)
hva --check-versions         check pinned vs latest upstream versions
hva --llama-cpp-update       update pinned llama.cpp image digest
hva --loop                   run tasks.md through repeated Pi passes
hva --loop-init              create tasks.md template
hva --loop-stop              stop loop after current iteration
hva --loop-status            show loop state
hva --reset-pi-cache         clear Pi home/config cache
hva --cleanup-docker         show Docker storage
hva --cleanup-docker --apply prune HVA containers/images (--volumes, --global-build-cache)
```

## Project isolation

`hva` does not read or write project agent files. The repo's `AGENTS.md`, `.pi/extensions`, `.pi/skills` are ignored. HVA loads its own extensions and skills explicitly.

## Config

`config/hva-conf.json` — all settings (model, context, sampling, mounts, MCP). See `config/hva-conf.json.sample`.  
`config/hva-secrets.json` — optional secrets (gitignored). See `config/hva-secrets.json.sample`.  
Full config reference and one-shot env overrides: [docs/docker.md](docs/docker.md).

## More info

- [Caveats](caveats.md)
- [Pi Docs](https://pi.dev/)
- [Pi Packages](https://pi.dev/packages)
- [Docker Setup](docs/docker.md)
- [Local Host Setup](docs/local.md)
