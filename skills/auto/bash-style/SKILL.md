---
name: bash-style
description: Use for bash and shell.
---

# Shell Safety

## Basics

- Always start with

```bash
#!/usr/bin/env bash
set -euo pipefail`
```

- Quote all variable expansions
- `[[ ]]` not `[ ]`
- `local` all function variables

## Arrays and paths

Use `"${arr[@]}"` not `$arr`. Use `-print0` with `read -d ''` when paths might have spaces.

## Gotchas

`set -e` doesn't fire inside conditions. For `local var=$(cmd)` the exit code is swallowed, so declare first and assign second.
