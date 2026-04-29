---
name: improve-codebase-architecture
description: Find architectural friction in an existing Rust codebase and propose functional Rust fixes. Use when you want to improve architecture, eliminate OOP patterns, push toward a pure core, or surface where logic, types, or boundaries are causing friction.
---

# Improve Codebase Architecture

Make friction visible and propose the functional Rust fix. This skill improves an **existing** codebase — it is orthogonal to type-design and TDD, which extend a codebase. When the grilling loop finishes on a candidate, the output is ready for type-design.

Use the vocabulary in [LANGUAGE.md](LANGUAGE.md). Use `CONTEXT.md` for domain terms.

## Process

### 1. Explore

Read `CONTEXT.md` and any ADRs in `docs/adr/` first. Familiarise yourself with [sans-io.md](../../auto/type-design/sans-io.md) — the pure core / async shell split is the pattern most of the friction signals below are defending.

Then walk the codebase looking for these five friction signals:

**1. Logic leaking into the shell**
`async` functions containing `if`/`else` business rules, math, or data transformations. Logic inside the shell can't be unit-tested purely — it requires integration testing or faking. Fix: push the logic into a synchronous core function and return a new `Action` variant.

**2. I/O leaking into the core**
`handle()` functions or domain logic that take `&mut DbConnection`, call `Instant::now()` internally, or use a `Mutex`. This destroys the sans-IO pattern — the core is no longer a pure state machine. Fix: pass time as an argument (`now: Instant`), replace I/O calls with `Action` variants.

**3. Shallow types and unvalidated boundaries**
Raw primitives (`String`, `i64`, `Uuid`) passed deep into core logic, or newtypes that lack a validated constructor (`parse()`, `TryFrom`). Fix: deepen the type — move validation into the constructor so the rest of the codebase can blindly trust it.

**4. The trait trap (premature polymorphism)**
Traits with only one implementer, or traits acting as OOP-style ports and adapters. Because the sans-IO core never needs injection or mocking, single-use traits are cognitive noise. Fix: delete the trait, use a concrete type or standalone function.

**5. State fragmentation**
Either: having to bounce between many small state machines to understand one concept, or an `Action` enum that has grown into a bloated catch-all (50+ variants). Fix: consolidate related states into a unified enum, or split a massive global core into domain-specific bounded cores. See [sans-io.md — Splitting and composition](../../auto/type-design/sans-io.md#splitting-and-composition) for the ordered decision process.

### 2. Present candidates

Present a numbered list. For each candidate:

- **Scope** — which files, structs, enums, or functions are involved
- **Friction** — which signal is occurring (name it from the five above)
- **Structural shift** — plain English: what type or boundary transformation would fix it
- **Benefits** — in terms of compiler guarantees, locality, and testability

Example:

> **1. Extract discount logic from billing shell**
> **Scope**: `src/shell/billing.rs` (`process_payment`), `src/core/order.rs`
> **Friction**: Logic leaking into the shell — `process_payment` calculates totals and discounts before calling Stripe.
> **Structural shift**: Extract into a pure `calculate_discount(&Order) -> Amount` in the core. Shell calls it, then executes the side effect.
> **Benefits**: Discount rules concentrated in one place. Testable as a pure function — no Tokio runtime or database stand-in needed.

Do NOT propose type signatures yet. Ask: "Which of these would you like to explore?"

### 3. Grilling loop

Once the user picks a candidate, enter a grilling conversation. Use the same discipline as `grill-with-docs`:

- One question at a time, waiting for an answer before continuing
- Provide your recommended answer with each question
- If a question can be answered by exploring the codebase, explore instead of asking
- Walk down the design tree — constraints, what moves to the core, what becomes an `Action`, what the type looks like

Side effects happen inline as decisions crystallise:

- **New term not in `CONTEXT.md`?** Add it immediately. See [CONTEXT-FORMAT.md](../grill-with-docs/CONTEXT-FORMAT.md).
- **Fuzzy term sharpened during conversation?** Update `CONTEXT.md` right there.
- **User rejects the candidate with a load-bearing reason?** Offer an ADR. Only offer when the reason would be needed by a future explorer to avoid re-suggesting the same thing. See [ADR-FORMAT.md](../grill-with-docs/ADR-FORMAT.md).

  Examples of load-bearing rejections worth recording:
  - "We can't wrap this in a newtype — the buffer is passed directly to a zero-copy DMA peripheral."
  - "Keep the trait — the V2 hardware board arrives next month and both firmwares must compile side-by-side."
  - "Don't merge these cores — `ConnectionState` lives on the network thread, `SessionState` requires async crypto."

When the grilling loop concludes, summarise the agreed redesign. The output is ready for type-design.

