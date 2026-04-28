# Hva'? (hva) - Local LLM Vibe Coding Setup - Using 'Pi Coding Agent' + 'llama.cpp'

- Local llama.cpp server (which runs the LLM) [Github Link](https://github.com/ggml-org/llama.cpp)
- Pi coding agent in a dev container (yolo mode without the git folder(or enable it in your config)) [Github Link](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent)

## Quick start

1. Add `scripts/` to your PATH
2. Download a `.gguf` model and put it in `models/`
3. Run `hva`

`config/hva-conf.json` is created automatically on first run.

## Recommended Models (Entire model does not have to be in VRAM)

### Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF

- Best relative speed/performance/vram usage (try to use 'Q4_K_M' even on low VRAM)
- Model Page [Link](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF)
- [i1-IQ3_S download (15.3 GB)](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF/resolve/main/Qwen3.6-35B-A3B-uncensored-heretic.i1-IQ3_S.gguf)
- [i1-Q4_K_M download (21.2 GB)](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF/resolve/main/Qwen3.6-35B-A3B-uncensored-heretic.i1-Q4_K_M.gguf)
- [i1-Q5_K_M download (24.7 GB)](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF/resolve/main/Qwen3.6-35B-A3B-uncensored-heretic.i1-Q5_K_M.gguf)
- [i1-Q6_K download (28.5 GB)](https://huggingface.co/mradermacher/Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF/resolve/main/Qwen3.6-35B-A3B-uncensored-heretic.i1-Q6_K.gguf)

### Qwen3.6-27B-heretic-heretic2-GGUF

- Not a MoE model (!Use the model above instead!)
- ONLY USE IF YOU HAVE TOO MUCH VRAM / DON'T CARE ABOUT SPEED (VRAM usage compared to '35B-A3B' is a 2 GB -> 9GB jump) + no 'i1' yet
- Model Page [Link](https://huggingface.co/mradermacher/Qwen3.6-27B-heretic-heretic2-GGUF)
- [Q4_K_M download (16.5 GB)](https://huggingface.co/mradermacher/Qwen3.6-27B-heretic-heretic2-GGUF/resolve/main/Qwen3.6-27B-heretic-heretic2.Q4_K_M.gguf)
- [Q5_K_M download (19.2 GB)](https://huggingface.co/mradermacher/Qwen3.6-27B-heretic-heretic2-GGUF/resolve/main/Qwen3.6-27B-heretic-heretic2.Q5_K_M.gguf)
- [Q6_K_M download (22.1 GB)](https://huggingface.co/mradermacher/Qwen3.6-27B-heretic-heretic2-GGUF/resolve/main/Qwen3.6-27B-heretic-heretic2.Q6_K.gguf)
- [Q8_0 download (28.6 GB)](https://huggingface.co/mradermacher/Qwen3.6-27B-heretic-heretic2-GGUF/resolve/main/Qwen3.6-27B-heretic-heretic2.Q8_0.gguf)

## Shell Completion

**bash** - add to `~/.bashrc`:

```bash
source /path/to/hva/completions/hva.bash
```

**fish** - symlink into completions:

```fish
ln -s /path/to/hva/completions/hva.fish ~/.config/fish/completions/hva.fish
```

## Useful commands inside Pi

- `/list-cmds` - show HVA custom commands and blessed flows
- `/list-skills` - show HVA skills by group
- `/use-skill` - pick a manual skill and insert the `/skill:...` call
- `/git` - prepare a local git review diff and send it to the agent
- `/skill:read-repo` - preview, ignore, and load a repo or subpath into context
- `/skill:hva-review` - run the HVA repo review checklist
- `/skill:hva-new-skill` - make or change HVA skills and extensions

## Commands

```
hva                          start/reuse llama, enter workspace, open Pi
hva --local                  start/reuse llama, then open host Pi
hva --bash                   shell into running dev container, or start one if needed
hva --new                    start a fresh Pi session (clears resume state)
hva --new-hard               start a fresh Pi session and recreate the dev container
hva --msg TEXT               one-shot Pi message
hva --prompt TEXT            one-shot Pi prompt (alias for --msg)
hva --prompt-file FILE       one-shot Pi prompt from file
hva --diff-review REV        review git diff from REV..HEAD
hva --diff-review-branch BRANCH
                             review git diff from merge-base(BRANCH, HEAD)..HEAD
hva --diff-review-main       review git diff from merge-base(main/master, HEAD)..HEAD
hva --diff-review-staged     review staged git diff
hva --diff-review-unstaged   review unstaged git diff
hva --diff-review-all        review tracked + untracked git diff without touching real index
hva --stop                   stop llama, searxng, and dev container
hva --start-searxng          start SearXNG helper container
hva --stop-searxng           stop SearXNG helper container
hva --update                 pull latest hva, ensure config exists, refresh Pi config
hva --reset-pi-cache         clear cached Pi config/home (rebuilt on next run)
hva --cleanup-docker [--apply] [--volumes] [--global-build-cache]
                             show Docker storage; prune HVA-owned leftovers when applied
hva --runtime-state [WORKSPACE]
                             print HVA state paths for this workspace
hva --daemon                 start llama server as background daemon
hva --healthcheck            compact llama health verdict; strict on cache invalidation
hva --llama-cpp-update       update pinned llama.cpp image digest, then pull it
hva --llama-cpp-logs-full    print full llama server container logs
hva --build-docker-prison    build dev image if missing/outdated (--force to rebuild anyway)
hva --check-versions         check pinned vs latest upstream versions
hva --loop [WORKSPACE]       run Pi loop mode using WORKSPACE/tasks.md
hva --loop-init [WORKSPACE]  create a tasks.md template in workspace root
hva --loop-stop [WORKSPACE]  ask a running loop to stop after this iteration
hva --loop-status [WORKSPACE]
                             print current loop status from workspace state
```

## Project isolation

`hva` does not read or write project agent files. The target repo's `AGENTS.md`, `.pi/extensions`, and `.pi/skills` are ignored. HVA loads its own stuff from `pi/extensions/`, `hva-runtime/`, `skills/`, and `skills-hva/`.

## Config

- `config/hva-conf.json` - all settings (model, context, sampling, mounts, MCP). See `config/hva-conf.json.sample`.
- `config/hva-secrets.json` - optional secrets (gitignored). See `config/hva-secrets.json.sample`.
- Full config reference and one-shot env overrides: [docs/docker.md](docs/docker.md).

## More info

- [Caveats](caveats.md)
- [Pi Docs](https://pi.dev/)
- [Pi Packages](https://pi.dev/packages)
- [Docker Setup](docs/docker.md)
- [Local Host Setup](docs/local.md)

## Adding a skill

- [docs/new-skill.md](docs/new-skill.md) - how to add a skill or extension. [docs/skill-basics.md](docs/skill-basics.md) for the mental model.
- Try opening `hva` and calling `/skill:hva-new-skill help me make a new skill for ...`
