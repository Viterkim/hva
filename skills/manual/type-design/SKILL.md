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
   - If rust-analyzer is unavailable or fails to find what you need, fall back to `grep`/`glob` on `*.rs` files within `src/`. If the codebase is still unclear after searching, ask the user which module contains the relevant domain entities before proceeding.
3. Run `cargo check` to confirm the baseline compiles. If it does not, stop and tell the user — do not proceed until the baseline is clean.
4. Summarise in one sentence what capability is being added. Confirm with the user before continuing.
5. **If the task requires a new module or crate**, follow the procedures in [architecture.md](architecture.md) before writing any types.

## Step size

- **Core concepts and important types**: one at a time — propose, discuss, write, move on
- **Helper types and small utility functions**: can be grouped when they only make sense together

For each type or group: propose with a brief rationale, **show the proposed definition in a code block in the chat**, wait for **explicit approval**, then write to the codebase using file tools. Do not use file-writing tools before approval.

## During the session

### Call out invalid states

For every type proposed, ask: "Is there a combination of these fields or values that would be invalid?" If yes, reach for an enum. See [rust-type-patterns.md](rust-type-patterns.md).

### Call out missing newtypes

If a raw primitive (`i64`, `String`, `Uuid`, `bool`) is about to cross a domain boundary, stop. Does it have a name? Give it a type. Default to proposing `#[nutype]` for validated newtypes — see [rust-type-patterns.md](rust-type-patterns.md) for when to use `TryFrom` instead.

### Call out sentinel values

No `0`, `-1`, empty string, or magic values to mean "missing" or "none". Use `Option<T>` or a typed enum variant. See [rust-type-patterns.md](rust-type-patterns.md).

### Flag `async` on logic functions

Pure functions are never `async`. If a proposed signature is `async` but would contain logic rather than side effects, flag it. See [rust-type-patterns.md](rust-type-patterns.md).

### Flag `&mut` outside `&mut self`

Any `&mut` that is not `&mut self` is a warning sign — flag it every time. It signals that ownership was not thought through. Fix the design, not the symptom.

### Consider the sans-IO pattern for stateful components

If a component holds mutable state and reacts to events, propose the sans-IO split — a pure sync core and an async shell. Logic stays in the core; the shell executes side effects and holds no logic. See [sans-io.md](sans-io.md).

### Watch for `Mutex`

If `Mutex` appears, stop. Fix the ownership design, not the symptom. See [rust-type-patterns.md](rust-type-patterns.md).

### Challenge unnecessary traits

Default to `impl Type`. If a trait is proposed, verify it fits one of the three approved use cases: standard library integration, shell boundary, or open-ended polymorphism. If it fits none, convert it to an inherent method. See [rust-type-patterns.md](rust-type-patterns.md).

### Flag leaky encapsulation

Do not add `derive(Deref)`, `derive(AsRef)`, or `derive(Into)` to domain newtypes unless explicitly crossing an outer boundary (database, serialisation, third-party API). Use explicit accessors (`into_inner()`, `as_str()`) instead. See [rust-type-patterns.md](rust-type-patterns.md).

### Assign intentional visibility

Every type and function written must have an explicit visibility decision — do not default to `pub`. See [rust-type-patterns.md](rust-type-patterns.md).

### Enforce the facade pattern

Types, traits, and functions must never be defined in a module root (`mod.rs` or `module.rs`). If creating or modifying a module root, apply the facade pattern. See [architecture.md](architecture.md).

### Flag circular dependencies

If a proposed type relationship would create a circular dependency between modules or crates, stop and flag it — this signals a domain boundary flaw. See [architecture.md](architecture.md).

### `todo!()` bodies

Every stub body must contain a comment explaining what the implementation is expected to do:

```rust
fn validate_token(token: &AuthToken) -> Result<Claims, AuthError> {
    todo!("decode JWT, verify signature against public key, return Claims or AuthError::InvalidToken")
}
```

### No tests

Do not write `#[test]` modules, `tests/` directories, or any test helper code. Tests belong to the TDD step. (Reference-doc examples in skill files are not affected by this rule.)

### Broken callers

If a new type or changed signature breaks existing callers, fix the callers with `todo!()` stubs. Do not implement logic to make them compile.

### Dependency management

When an approved design requires a crate not already present (e.g., `nutype`, `thiserror`, `derive_more`), run `cargo add -p <package> <crate>` for the target package using the terminal before writing the type. Include any required feature flags (e.g., `cargo add -p my-crate thiserror`).

## Compile check

After writing each agreed group, run `cargo check` (or `cargo check -p <package>` for a specific crate) using the terminal. Read the output and fix compile errors autonomously — do not pause unless:

- The error requires a design decision (not a mechanical fix)
- The error reveals that an approved type is wrong at the domain level

Autonomous fixes are limited to: missing imports, visibility adjustments, module wiring, and `todo!()` stub propagation to broken callers. Any new public type, trait, signature, or dependency still requires explicit user approval first.

Run `cargo check --workspace` before declaring the session done.

## Done

When `cargo check --workspace` passes and there is nothing left to discuss, close the session by printing a **Handoff Manifest** — a consolidated markdown summary that gives the TDD agent a clear starting point:

- All types and traits introduced, with their module path and visibility
- Architectural changes: new modules created, facade patterns updated, new workspace crates added
- Crates added via `cargo add`
- Callers updated with `todo!()` stubs
- Open questions or decisions deferred to the TDD step
