# Caveats

## Nanocoder patches

- GitHub nanocoder specs build from source so unreleased commits work
- `docker/Dockerfile.safeprison` patches compiled JS for container trust at build time
- patches: `useDirectoryTrust.js` (container trust), `useAppHandlers.js` (session auto-resume), `useAppInitialization.js` (await MCP before ready signal for consistent system prompt), `conversation-loop.js` (preserve full assistant content for history/cache reuse), `useSessionAutosave.js` (flush pending autosave work on shutdown)
- each compiled patch is verified with `grep -q`, so docker build fails loudly if it stops matching after a nanocoder update

## C# LSP

- csharp-ls is registered with nanocoder's LSP server discovery via the same sed mechanism
- opt-in: `HVA_CSHARP=true hva --build-docker-prison` (off by default)
- same caveat as above: more sed surface area for a narrow use case
- even when installed, `HVA_LSP_ENABLED` / `HVA_LSP_DISABLED` can still mask it at runtime

## Docker flags

- opt-in: `HVA_UNSAFE=1`
- `--cap-add SYS_PTRACE` + `--security-opt seccomp=unconfined`: needed for debuggers (gdb, strace, valgrind) inside the container
- `-v /var/run/docker.sock:/var/run/docker.sock`: lets the container run docker commands on the host
- NOTE: the container is not a strong security boundary when unsafe mode is on

## Host config mounts

- opt-in with `HVA_MOUNT_GITCONFIG=1` and `HVA_MOUNT_NVIM=1`
- `~/.ssh` is opt-in through `HVA_MOUNT_SSH=1`
