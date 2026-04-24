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
- `hva --update`: pull latest hva, sync env vars, auto-refresh managed config
- `hva --reset-nanocoder-cache`: clear cached nanocoder config
- `hva --daemon`: start llama server in background
- `hva --healthcheck`: compact llama health verdict
- `hva --llama-cpp-logs-full`: full llama container logs
- `hva --build-docker-prison`: build dev image if missing/outdated (`--force` to rebuild anyway)
- `hva --check-versions`: check pinned vs latest upstream versions
- `hva --llama-cpp-update`: update pinned llama.cpp image digest, then pull it
- `hva --loop`: run `tasks.md` in the workspace root through one long-lived container
- `hva --loop-init`: create a root `tasks.md` template with loop settings
- `hva --loop-stop`: ask the current loop to stop after the running iteration
- `hva --loop-status`: show the current loop state from `.hva-state/loop/status`

## Loop Mode

`hva --loop` always reads `tasks.md` from the workspace root. Use `hva --loop-init`
to create the standard file. The dumb standard is:

- `loop_hours`
- `loop_minutes`
- `loop_max_iterations`
- `loop_review`
- `loop_improve`

Loose bullets or numbered steps are allowed. The first loop pass will try to
normalize them into checkbox tasks before working. When the time limit runs
out, the loop finishes the current iteration and stops before the next one.

## Managed AGENTS

By default `hva` manages `AGENTS.md` for each workspace:

- absent `AGENTS.md` -> create a managed symlink
- old hva-generated copy -> migrate it to the managed symlink
- custom `AGENTS.md` -> leave it alone
- extra local tweaks -> put them in `AGENTS.local.md`

Generated workspace files are added to `.git/info/exclude` when possible so
they stop cluttering `git status`.

## Qwen3.6 Defaults

The llama wrapper now exposes sampling and thinking flags through
`env/env-source.sh`. The default profile matches Qwen3.6 thinking-mode guidance
for precise coding work: thinking enabled, preserve thinking enabled,
`temperature=0.6`, `top_p=0.95`, `top_k=20`, `min_p=0`, `presence_penalty=0`.

## More Info

- More [Docker Setup Docs](docs/docker.md)
- Extra Optional [Native Nanocoder setup](docs/local.md)
- Censored: [Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf) · [model page](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF)
- Uncensored: [Qwen3.6-35B-A3B-uncensored-heretic.i1-Q5_K_M.gguf](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF/resolve/main/Qwen3.6-35B-A3B-uncensored-heretic.i1-Q5_K_M.gguf) · [model page](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF)
