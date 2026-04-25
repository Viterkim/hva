# Caveats

## Docker socket (host escape)

- `HVA_MOUNT_DOCKER_SOCKET=0` — default: container cannot touch host Docker
- `HVA_MOUNT_DOCKER_SOCKET=1` — mounts `/var/run/docker.sock`; container can start/stop/delete host containers
- The container is NOT a security boundary when the Docker socket is mounted

## ptrace and seccomp (debug mode)

- Default container runs without `--cap-add SYS_PTRACE` and without `seccomp=unconfined`
- Set `HVA_UNSAFE=1` in config only when you need debugger-heavy sessions
- Those flags weaken kernel isolation

## SSH, gitconfig, Neovim mounts

- `HVA_MOUNT_SSH=1` — mounts `~/.ssh` read-only; agent can use host SSH keys and identities
- `HVA_MOUNT_GITCONFIG=1` — mounts `~/.gitconfig` read-only; commits will use your host identity
- `HVA_MOUNT_NVIM=1` — mounts `~/.config/nvim` and `~/.local/share/nvim` read-only

## pi-lens state

- pi-lens writes `.pi-lens/` cache into the workspace; HVA mounts that path as tmpfs
- Cache is ephemeral — gone when the dev container stops; pi-lens rebuilds on next start

## SearXNG disabled engines

- `wikidata`, `ahmia`, `torch` removed via `use_default_settings.engines.remove` in `internals/searxng-settings.yml`
- Reason: wikidata crashes on startup (upstream API broke), ahmia and torch are TOR indexers that fail to load
- Settings and limiter stub are copied into the container before start; no host temp dir is reused
- All standard web search engines (DuckDuckGo, Bing, Google, etc.) remain active

## Local mode needs host Node

- `docs/local.md` describes running Pi directly on the host (not in container)
- Local mode requires host Node, npm, and extension deps installed on the host machine
- Docker mode does not need host Node
