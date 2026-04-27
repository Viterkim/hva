# Caveats

## Docker socket (host escape)

- `HVA_MOUNT_DOCKER_SOCKET=0` - default: container cannot touch host Docker
- `HVA_MOUNT_DOCKER_SOCKET=1` - mounts `/var/run/docker.sock`. Container can start/stop/delete host containers
- The container is NOT a security boundary when the Docker socket is mounted

## ptrace and seccomp (debug mode)

- Default container runs without `--cap-add SYS_PTRACE` and without `seccomp=unconfined`
- Set `HVA_UNSAFE=1` in config only when you need debugger-heavy sessions
- Those flags weaken kernel isolation

## SSH, gitconfig, Neovim mounts

- `HVA_MOUNT_GIT=1` - leaves `.git` metadata visible inside the workspace mount. The agent can inspect repo status, history, and diffs from inside the container
- `HVA_MOUNT_SSH=1` - mounts `~/.ssh` read-only. Agent can use host SSH keys and identities
- `HVA_MOUNT_GITCONFIG=1` - mounts `~/.gitconfig` read-only. Commits will use your host identity
- `HVA_MOUNT_NVIM=1` - mounts `~/.config/nvim` and `~/.local/share/nvim` read-only
