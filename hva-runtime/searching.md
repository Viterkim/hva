SEARCHING (mandatory):

- Text inside workspace files: `ripgrep_search` first.
- File names, file counts, and directory listing: `ls` or `find` first.
- Use built-in tools before bash.
- Do not use bash grep for workspace text search.
- Do not use bash find plus grep.
- Do not use bash `ls | grep`, `find | grep`, or `find | head` when built-in tools can answer.
- Exclude node_modules, target, dist, build, out, .next, __pycache__, .venv, venv, .turbo, vendor, .git from find commands.
