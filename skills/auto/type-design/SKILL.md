---
name: type-design
description: "Pair programming session to design Rust types, traits, and function signatures before any implementation. Produces compiling stubs with todo!() bodies. Types are frozen after this session — TDD fills in implementations, never reshapes the interface."
---

# Type Design

Pair programming session focused purely on types, traits, and function signatures. Nothing is implemented. The output is compiling Rust stubs that define the interface contract for the TDD step.

**The model has the keyboard. You drive the direction.**

## Contract

When this session ends:

- All types, traits, and function signatures are **frozen**
- The codebase compiles (`cargo check` passes)
- No logic exists — only `todo!()` bodies with a comment describing the expected implementation

The TDD step fills in implementations and writes tests against these interfaces. It does not reshape them. If TDD reveals a type was wrong, stop TDD and re-invoke type-design.

## Before starting

1. **Understand the task.** The user points you at what to work on — a task file, a description, or a specific module. Ask if anything is unclear before proceeding.
2. **Explore the codebase — targeted, not broad:**
   - Read `CONTEXT.md` for domain vocabulary if it exists.
   - Use rust-analyzer (LSP) to find what you need — do not read entire files unless necessary:
     - **Workspace symbol search** — look up types and traits mentioned in the task by name.
     - **Go to definition** — inspect the definition of any relevant type or trait.
     - **Find references** — check how existing domain types are used to maintain naming consistency.
   - If rust-analyzer cannot locate what you need, ask the user which module contains the relevant domain entities before proceeding.
3. Run `cargo check` to confirm the baseline compiles. If it does not, stop and tell the user — do not proceed until the baseline is clean.
4. Summarise in one sentence what capability is being added. Confirm with the user before continuing.

## Step size

- **Core concepts and important types**: one at a time — propose, discuss, write, move on
- **Helper types and small utility functions**: can be grouped when they only make sense together

For each type or group: propose with a brief rationale, wait for **explicit approval**, then write to the codebase. Do not write anything before approval.

## During the session

### Call out invalid states

For every type proposed, ask: "Is there a combination of these fields or values that would be invalid?" If yes, reach for an enum. See [rust-type-patterns.md](rust-type-patterns.md).

### Call out missing newtypes

If a raw primitive (`i64`, `String`, `Uuid`, `bool`) is about to cross a domain boundary, stop. Does it have a name? Give it a type. Two reasons matter — see [rust-type-patterns.md](rust-type-patterns.md).

### Call out sentinel values

No `0`, `-1`, empty string, or magic values to mean "missing" or "none". Use `Option<T>` or a typed enum variant. Applies to all types, not just structs.

### Flag `async` on logic functions

If a proposed function signature is `async` but contains logic rather than a side effect, flag it. Pure functions are never `async`. A simple `if pure_predicate()` or top-level `match` in an async orchestration function is acceptable — loops and nested branching are not. See [rust-type-patterns.md](rust-type-patterns.md).

### Flag `&mut` outside `&mut self`

Any `&mut` that is not `&mut self` is a warning sign — flag it every time. It signals that ownership was not thought through. Fix the design, not the symptom.

### Consider the sans-IO pattern for stateful components

If the work involves a component that holds mutable state and reacts to events, propose the sans-IO split — a pure sync core and an async shell. Mutable state is the primary signal. See [sans-io.md](sans-io.md).

### Watch for `Mutex`

If `Mutex` appears, stop. It means ownership of that data is unclear. This applies during type design: if you are designing how components share or communicate data, clarify which component owns it and let Rust's ownership model enforce it — fix the design, not the symptom.

## Types in detail

### Derives

Add common derives during type-design: `Debug`, `Clone`, `PartialEq`, and `Eq` where they apply. If a type must not be cloned freely, omit `Clone` intentionally and note why.

### Visibility

Decide visibility (`pub`, `pub(crate)`, or private) for every type and function as part of this session. Visibility is an interface decision, not an implementation detail.

### Newtypes and conversion traits

For newtypes, design the full interface here — see [rust-type-patterns.md](rust-type-patterns.md) for detail and examples:

- **Construction** — `From<Inner>` (infallible) or `TryFrom<Inner>` (validated). Define the domain error enum alongside `TryFrom`.
- **Strict encapsulation** — the core operates on domain types, not primitives. No `.as_ref()`, `.into()`, or public inner access within the domain. Behaviour belongs on the type. Do not derive `AsRef`, `Deref`, or `Into` unless crossing a boundary.
- **Explicit accessors** — `into_inner(self)` / `as_str(&self)` only where the type crosses an outer boundary (database, serialisation, third-party API). Their verbosity is intentional.
- **`nutype`** — prefer it over manual `TryFrom` boilerplate when validation is required (bounds, length, regex).

`Display`, `Serialize`, `Deserialize`, and similar are implementation details — leave them for TDD unless they are part of the public interface.

### Traits

Default to inherent methods (`impl Type`). Propose a trait only when one of the following is true:

1. **Standard library integration** — parsing or validated construction via `FromStr`, `TryFrom`, etc.
2. **Shell boundary** — the async shell needs to execute an action across interchangeable implementations (e.g., `HardwareGateway`, `EmailSender`).
3. **Open-ended polymorphism** — multiple distinct types in the core need to be treated uniformly and an enum does not fit.

If none of these apply, use a function or inherent method.

### Error types

Design the main shape of error types here — the variants that represent domain-level failure. TDD is allowed to add variants for errors originating from external crates, since those are only known at implementation time.

### `todo!()` bodies

Every stub body must contain a comment explaining what the implementation is expected to do:

```rust
fn validate_token(token: &AuthToken) -> Result<Claims, AuthError> {
    todo!("decode JWT, verify signature against public key, return Claims or AuthError::InvalidToken")
}
```

## Compile check

After each agreed group is written, run `cargo check`. Fix compile errors before moving on. The codebase must compile at every step.

## Done

When `cargo check` passes and there is nothing left to discuss, the session is complete.
