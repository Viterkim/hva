---
name: ripgrep
description: "Use first for workspace search: code text, errors, logs, config keys, symbol names, repeated snippets, references, and which files mention something."
---

# Ripgrep

Use `ripgrep_search` first when the user wants to find something inside workspace files.

This is the default move for:

- code text
- references
- config keys
- symbol names
- error strings
- logs
- repeated snippets
- which files mention something
- where something is used
- where a message comes from

Do this instead of bash `grep`, `find | grep`, or `ls | grep`.

If one query misses, try another pattern or a glob before assuming absence.

If the task is about file names, file counts, or directory listing, use `ls` or `find` tools instead.
