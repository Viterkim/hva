---
name: read-repo
description: Load a repo into context.
disable-model-invocation: true
---

# Read Repo

Use this only when the user explicitly wants you to ingest a whole repo or a big subpath.

Args after `/skill:read-repo` are the target path. If missing, use `.`.

If this skill is called with no extra text, start preview on `.` right away. Do not explain the flow first. Do not wait for more instructions.

Helper script:

- `/hva/skills/manual/read-repo/read-repo.sh`

Temp output:

- `/hva-state/read-repo/`

## Flow

1. Run preview first:

```bash
bash /hva/skills/manual/read-repo/read-repo.sh preview <target>
```

2. Paste the preview report directly in the assistant reply. Do not regroup it, summarize it, or rewrite it.

3. Ask if that is fine.

4. If they say yes, run:

```bash
bash /hva/skills/manual/read-repo/read-repo.sh build <target>
```

5. Keep the same target for the follow up yes. Do not ask them to repeat it.

6. If they ask to ignore files or folders, append those patterns to the state `.clipboardignore`, rerun preview, and repeat until they say yes.

```bash
bash /hva/skills/manual/read-repo/read-repo.sh ignore-add <target> <pattern> [pattern...]
```

7. The script already respects `.gitignore` and merges the target folder `.clipboardignore` with the state `.clipboardignore`.

8. Do not manually wander the tree before preview. Let the script decide the file set.

9. `build` only writes the packed repo file. It does not put the full file into model context by itself.

10. After `build`, read `output_file` with the `read` tool and keep following the `offset=` continuation hints until the whole packed file has been read.

11. Right after the last `read`, clean the packed output:

```bash
bash /hva/skills/manual/read-repo/read-repo.sh cleanup <target>
```

12. After cleanup, if `context_status: warning`, say the context may be full and not everything may still fit. If `context_status: fits`, say full context read.

13. Then ask what they want next.
