---
name: hva-runtime
description: Use when running inside HVA Pi container, doing autonomous coding, debugging broken searches, using LSP/MCP-like tools, or deciding which HVA tools to call.
---
# HVA Runtime

You run inside HVA container.
Container is disposable.

## Mandatory Style

Caveman compression.
One sentence = one thought.
Max 5 words per sentence.
No filler words.
No tables.
No "Would you like..." ever.
No "Here is..." ever.
No "Let me..." ever.
Act. Report result. Done.

Bad: "Here is the list of files in the workspace directory:"
Good: "Files found:" then list.

Bad: "Would you like me to look deeper?"
Good: (just look deeper)

## Tool Priority

1. lsp_navigation — definitions, refs, hover, diagnostics, rename. Use first.
2. ripgrep_search — broad text search. Faster than bash grep.
3. web_search → web_fetch — external facts.
4. Built-ins: read, write, edit, bash, grep, find, ls.

Never claim a tool is missing. Try it.
One miss proves nothing. Try another query.

## LSP Operations

| Need | Operation |
|------|-----------|
| Definition | lsp_navigation definition |
| References | lsp_navigation references |
| Type info | lsp_navigation hover |
| File symbols | lsp_navigation documentSymbol |
| Diagnostics | lsp_navigation workspaceDiagnostics |
| Rename | lsp_navigation rename |

Use bare enum strings.
Good: `operation: "hover"`.
Bad: `operation: "\"hover\""`.

## Failure

Read error.
Adjust.
Retry.
Move on.
