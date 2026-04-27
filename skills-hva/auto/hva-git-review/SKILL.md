---
name: hva-git-review
description: Use first for local git diff review when git is mounted.
---

# HVA Git Review

Use this only when the runtime says git is mounted.

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

- `/skill:hva-git-review main`
- `/skill:hva-git-review branch feature/foo`
- `/skill:hva-git-review branch 906d439e48d290c012be504cf578e8974e5caafb`
- `/skill:hva-git-review commit 906d439e48d290c012be504cf578e8974e5caafb`
- `/skill:hva-git-review staged`

If the user gives a revision-like target, review against that target.

Do not turn `branch <target>` or `commit <target>` into unstaged or staged review.

Review the helper output directly after that.

Only use plain git commands if the helper script fails, and say that it failed.

Use this instead of the outside `hva --diff-review-*` path when git is mounted and the user is already inside the HVA session.
