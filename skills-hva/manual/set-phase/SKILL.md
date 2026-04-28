---
name: set-phase
description: "Enter a development phase (1–4) and lock behaviour to that phase's rules."
disable-model-invocation: true
---

# Set Phase

Switches the active development phase. Takes one argument: 1, 2, 3, or 4.

Also responds to natural language like "enter phase 2" or "switch to phase 3".

## Step 1 — Identify the phase

Read the argument or the user's message. Extract the phase number: 1, 2, 3, or 4.

If no valid phase number is found, list the four phases and stop:

- Phase 1 (Architecture): high-level goals and constraints only, no code
- Phase 2 (Roadmap): user stories in stage files, no code
- Phase 3 (Detailed Planning): schemas and type signatures only, no implementations
- Phase 4 (Execution): implementation bodies only, existing types are frozen

## Step 2 — Overwrite `/hva-state/ACTIVE_PHASE.md`

Write the file using the exact rules below for the requested phase. Overwrite completely — do not append.

---

### Phase 1 — Architecture

```
# Active Phase: 1 (Architecture)

Start every response with exactly: I am in Phase 1 (Architecture)

## Rules

- NO code of any kind. Not even pseudocode or inline snippets.
- Your only output artifact is `architecture.md` in the workspace root.
- `architecture.md` must be under 1000 words.
- Write high-level goals, system constraints, and key trade-offs only.
- Do not reference implementation details, libraries, or schemas.

## Before writing architecture.md

1. Check for `CONTEXT.md` and `docs/adr/` at the workspace root. Read them if present.
   Do not re-litigate any decision that already has an ADR.

2. Interview relentlessly about every aspect of the system until reaching shared understanding.
   Walk down each branch of the design tree, resolving dependencies between decisions
   one-by-one. For each question, provide your recommended answer.
   Ask one question at a time, waiting for the answer before continuing.
   Good starting branches: primary user and problem, hard constraints, explicit non-goals,
   definition of success, key trade-offs — but follow every branch that opens, not just these.

3. When a term is resolved during the conversation, write or update `CONTEXT.md` immediately.
   Only include terms meaningful to a domain expert — no implementation details.
   Create the file lazily: only when the first term is ready to record.

4. When a decision is hard to reverse, surprising without context, and the result of a
   genuine trade-off between real alternatives — offer to record it as an ADR in
   `docs/adr/`. Offer sparingly. If any of the three conditions is missing, skip it.

5. Only write `architecture.md` once the grilling has reached shared understanding.
   Use only vocabulary from `CONTEXT.md`.
```

---

### Phase 2 — Roadmap

```
# Active Phase: 2 (Roadmap)

Start every response with exactly: I am in Phase 2 (Roadmap)

## Rules

- NO code of any kind.
- Read `architecture.md` before doing anything else.
- Break the architecture into sequential, logical stages.
- Create one file per stage named `stage_NN_<short-name>.md`
  (e.g. `stage_01_auth.md`, `stage_02_datastore.md`).
- Each stage file contains:
  - User stories: what the user can do after this stage is complete.
  - Technical requirements: what must be built to enable those stories.
  - Scope note: what is explicitly deferred to a later stage.
  - Unlocks: what this stage makes possible for the next stage.
- Limit scope to what is absolutely necessary for that stage.
  Defer anything not strictly required.

## Vocabulary lock

Use only terms defined in `architecture.md` and `CONTEXT.md`.
If a user story or requirement introduces a new term, stop and resolve it:
add it to `CONTEXT.md` before continuing.
```

---

### Phase 3 — Detailed Planning

```
# Active Phase: 3 (Detailed Planning)

Start every response with exactly: I am in Phase 3 (Detailed Planning)

## Rules

- ONLY output: PostgreSQL schemas and Rust types / traits / function signatures.
- NO implementation logic. NO function bodies. NO pseudocode.
- Signatures must be complete compilable stubs only (e.g. `todo!()` or `unimplemented!()`).
- Do not write prose beyond a single doc comment per item.
```

---

### Phase 4 — Execution

```
# Active Phase: 4 (Execution)

Start every response with exactly: I am in Phase 4 (Execution)

## Rules

- ONLY write implementation logic and function bodies.
- DO NOT modify existing Rust types, traits, or PostgreSQL schemas.
- DO NOT add new types or schemas.
- HALT CONDITION: If the logic cannot be implemented using the existing types and schemas,
  STOP immediately. Write no code. State exactly what is missing and ask the user for
  guidance before proceeding.
```

---

## Step 3 — Confirm and adopt

After writing the file, reply with one short line:

> Phase X (Title) is now active. [One sentence on what is and is not allowed.]

Then immediately operate under those rules for the rest of this session.
