---
name: ripgrep
description: Use first for workspace text search and pattern search.
---

# Ripgrep

Use `ripgrep_search` first for text inside workspace files.

Do this instead of bash `grep`, `find | grep`, or `ls | grep`.

Do not start with shell search if `ripgrep_search` can answer it.

Use it when the task is about text inside files.

Examples:

- find a string
- find a symbol name
- find config keys
- find repeated code or logs

If one query misses, try another pattern or a glob before assuming absence.

If the task is about file names, file counts, or directory listing, use `ls` or `find` tools instead.
