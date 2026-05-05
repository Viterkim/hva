---
name: to-prd
description: Synthesize the current conversation context into a PRD and save it to the project. Use after a grill-with-docs session when you are ready to commit the feature to paper.
---

# To PRD

Synthesize the current conversation context into a PRD. Do NOT interview the user — everything you need is already in the conversation. Just write.

## Before starting

1. Explore the repo to understand the current state of the codebase, if you haven't already.
2. Read `CONTEXT.md` if it exists — use the project's domain vocabulary throughout the PRD.
3. Sketch the major modules that need to be built or modified. Actively look for opportunities to extract deep modules — ones that encapsulate significant logic behind a simple, stable, testable interface.
4. Confirm the module list with the user before writing the PRD.

## Output location

Create the feature folder and PRD file:

```
ongoing-features/<slug>/prd.md
```

Choose a slug that names the feature clearly: `add-payments`, `user-can-reset-password`, `wire-up-webhooks`.

If `ongoing-features/` does not exist, create it. Remind the user to add `ongoing-features/` to their `.gitignore` if it isn't already there.

## PRD template

```markdown
# PRD: {Feature Name}

## Problem Statement

The problem the user is facing, from the user's perspective.

## Solution

The solution, from the user's perspective.

## User Stories

A numbered list covering all aspects of the feature. Each story:

1. As a <role>, I want <capability>, so that <benefit>.

Be exhaustive — include edge cases and secondary actors.

## Implementation Decisions

What will be built or modified:

- The modules that will be built or modified
- Interface changes
- Architectural decisions
- Schema changes
- API contracts
- Technical clarifications

Do NOT include specific file paths or code snippets — they go stale.

## Testing Decisions

- What makes a good test for this feature (test external behaviour, not implementation details)
- Which modules will have tests written
- Prior art: similar tests already in the codebase

## Out of Scope

What is explicitly not part of this feature.

## Further Notes

Anything else worth capturing.
```
