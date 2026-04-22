# Feature: CLI flag to start nanocoder in a specific session

There is no way to resume a session from the CLI. The session picker exists in
the UI but is unreachable in headless mode.

## Requested

```bash
nanocoder --resume last          # most recent session for cwd
nanocoder --resume <session-id>  # specific session
```

## Implementation

On startup with `--resume`, call `sessionManager.loadSession(id)` and
`applySession(session)` before first render. Scope `last` to sessions where
`workingDirectory === process.cwd()` so sessions from different projects don't
bleed into each other.
