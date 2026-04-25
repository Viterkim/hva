# Local Pi

Use this only when you want Pi on the host instead of in the Docker dev container.

Host mode still uses Docker for llama.cpp and SearXNG.

## Setup

Print the host setup commands:

```bash
./print-setup-instructions.sh local
```

Host mode needs host Node/npm because Pi extension dependencies are installed on the host.

## Run

```bash
hva --local
```

`hva --local` does the normal HVA startup path, then launches host Pi with the same explicit HVA extensions and skills.

If needed, `PI_CODING_AGENT_DIR` still overrides the default `~/.pi/agent`.
