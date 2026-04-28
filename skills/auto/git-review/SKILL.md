---
name: git-review
description: "Use for explicit local diff review targets when git is available."
---

# Git Review

Use this only when git is available in the session.

Use it when the user wants review against `main`, another branch, a commit, staged changes, unstaged changes, or all local changes from inside the session.

First action: run the helper script.

Do not start with `git diff`, `git status`, or `git log`.

Do not reinterpret the request into some other review mode.

Args:

- `main`
- `branch <target>`
- `commit <rev>`
- `staged`
- `unstaged`
- `all`

If called with no args, default to `main`.

Run exactly one of these first:

- `bash /hva/internals/git-diff.sh main "" /workspace`
- `bash /hva/internals/git-diff.sh branch <target> /workspace`
- `bash /hva/internals/git-diff.sh commit <rev> /workspace`
- `bash /hva/internals/git-diff.sh staged "" /workspace`
- `bash /hva/internals/git-diff.sh unstaged "" /workspace`
- `bash /hva/internals/git-diff.sh all "" /workspace`

Examples:

- `/skill:git-review main`
- `/skill:git-review branch feature/foo`
- `/skill:git-review branch 906d439e48d290c012be504cf578e8974e5caafb`
- `/skill:git-review commit 906d439e48d290c012be504cf578e8974e5caafb`
- `/skill:git-review staged`

If the user gives a revision-like target, review against that target.

Do not turn `branch <target>` or `commit <target>` into unstaged or staged review.

Review the helper output directly after that.

Only use plain git commands if the helper script fails, and say that it failed.
