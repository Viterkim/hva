# Hva'? (hva) - Local Vibecode Setup

- Local llama.cpp server
- Nanocoder in a yolo-mode dev container (with lsp + mcp setup)

## Quick start

1. Add `scripts/` to your PATH
2. Download a `.gguf` model and put it in `models/`
3. Run `hva` from any project

That's it. `env/env-source.sh` is created automatically on first run. If there's only one `.gguf` in `models/`, it's used automatically — no config needed.

```bash
hva
```

## Useful commands

- `hva --bash`: shell in dev container
- `hva --msg "text"`: one-shot Nanocoder message
- `hva --prompt "text"`: one-shot Nanocoder message (alias for --msg)
- `hva --prompt-file FILE`: one-shot Nanocoder run from file
- `hva --diff-review-main`: code review diff vs main/master
- `hva --diff-review-branch BRANCH`: code review diff from merge-base(BRANCH)
- `hva --diff-review-unstaged`: code review unstaged changes
- `hva --diff-review-staged`: code review staged changes
- `hva --diff-review-all`: code review all tracked + untracked changes
- `hva --diff-review SHA`: code review from SHA to HEAD
- `hva --stop`: stop llama server and searxng
- `hva --start-searxng`: start SearXNG web search container
- `hva --stop-searxng`: stop SearXNG container only
- `hva --update`: pull latest hva, clear stale nanocoder cache
- `hva --reset-nanocoder-cache`: clear cached nanocoder config
- `hva --daemon`: start llama server in background
- `hva --healthcheck`: compact llama health verdict
- `hva --llama-cpp-logs-full`: full llama container logs
- `hva --build-docker-prison`: build dev image if missing/outdated (`--force` to rebuild anyway)
- `hva --check-versions`: check pinned vs latest upstream versions
- `hva --llama-cpp-update`: update pinned llama.cpp image digest, then pull it

## More Info

- More [Docker Setup Docs](docs/docker.md)
- Extra Optional [Native Nanocoder setup](docs/local.md)
- Censored: [Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf) · [model page](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF)
- Uncensored: [Qwen3.6-35B-A3B-uncensored-heretic.i1-Q5_K_M.gguf](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF/resolve/main/Qwen3.6-35B-A3B-uncensored-heretic.i1-Q5_K_M.gguf) · [model page](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF)
