---
name: to-issues
description: Break a PRD into independently-grabbable issues on the feature's local kanban board using tracer-bullet vertical slices. Use when user wants to convert a PRD into kanban issues. Requires a PRD file created by the to-prd skill.
---

# To Issues

Break a PRD into independently-grabbable kanban issues using vertical slices (tracer bullets).

## Input

This skill works from a PRD file. Ask the user which PRD to work from if it isn't already clear from context. Read the PRD before doing anything else.

## Kanban board location

Issues live inside the feature folder alongside the PRD, organized into three subfolders:

```
ongoing-features/<slug>/
├── prd.md
└── kanban/
    ├── todo/
    ├── doing/
    └── done/
```

Each issue is its own markdown file named after what it does — no numbers, no ordering. New issues always land in `todo/`. Choose a slug that describes the work clearly: `user-can-reset-password.md`, `wire-up-payment-webhook.md`. The filename is the identity of the issue — make it say something.

## Process

### 1. Gather context

Read the PRD from `ongoing-features/<slug>/prd.md`. If the user references an existing kanban issue (by filename or title), read it from the feature's kanban folder first.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Issue titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

### 3. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
</vertical-slice-rules>

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Are the correct slices marked as HITL and AFK?

Iterate until the user approves the breakdown.

### 5. Write the issues to the kanban board

Create `ongoing-features/<slug>/kanban/todo/` if it does not exist. For each approved slice, create a file at `ongoing-features/<slug>/kanban/todo/descriptive-slug.md` using the template below. The slug must describe the work — not be a number or generic label.

Write files in dependency order (blockers first) so you can reference real filenames in the "Blocked by" field.

<issue-template>
# {Title}

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Type

HITL / AFK

## Blocked by

- `ongoing-features/<slug>/kanban/todo/other-issue-slug.md` (if any)

Or "None - can start immediately" if no blockers.
</issue-template>

To move an issue between columns, move its file to the corresponding folder (`doing/` or `done/`). Do not rename the file.
