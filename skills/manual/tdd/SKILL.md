---
name: tdd
description: "Implement Rust functions using red-green-refactor. Types and signatures are already frozen from the type-design step — do not reshape them. Use after type-design has run and the codebase has compiling stubs."
---

# Test-Driven Development

## Starting point

The type-design session already ran. The codebase has compiling stubs — types, traits, and function signatures with `todo!()` bodies. **Do not change any of these. This is absolute.** Your job is to fill them in.

If `CONTEXT.md` exists, read it for domain vocabulary and use that language in test names. Otherwise draw vocabulary from the stub names and `todo!()` comments.

Read the stubs and order them by dependency: **leaf functions first, their callers after**. Start from the bottom of the dependency graph.

## Safety valve

Stop immediately and ask for guidance if either of these is true:

- **The logic requires a state the type cannot represent.** The implementation is not wrong — the type is.
- **The only path forward requires `unsafe`, `Mutex`, or a workaround the type-design session explicitly banned.** Do not paper over it.

These are design failures, not implementation challenges. Do not work around them.

## Where tests live

- **Unit tests**: inline `#[cfg(test)]` module at the bottom of the source file.
- **Integration tests**: `tests/` directory.

## Functions and where logic lives

Logic lives in **free functions**. `impl` blocks contain:

- Constructors (`new`, `from`, `try_from`, `parse`)
- Conversions (`From`, `TryFrom`, etc.)
- `&mut self` state transitions

`&self` methods are acceptable when the operation logically belongs to the type. When in doubt, prefer a free function — take the data as an explicit parameter.

If during TDD you need to extract a helper, make it a free function unless it's a constructor, conversion, or mutation.

## Testing model

Every pure function is tested — regardless of visibility. 100% branch coverage is required and enforced with a coverage tool.

**Free functions and `&self` methods**: call with inputs, assert on the output. No mocks, no setup, no ceremony.

**`&mut self` state transitions**: construct the value, call the method, assert on the return value or the observable state change.

**Async functions** are kept intentionally logic-free — they orchestrate side effects only. There is nothing to unit test.

**Sans-IO machines** return `Vec<Action>`. Assert on the returned actions directly. No mocks needed. See [sans-io.md](../../auto/type-design/sans-io.md).

Mocking is not a technique used here. The code is designed so it is never needed. See [tests.md](tests.md).

## Anti-Pattern: Horizontal Slices

**Do not write all tests first, then all implementation.** One test → one implementation → repeat.

```
WRONG:  test1, test2, test3 → impl1, impl2, impl3
RIGHT:  test1 → impl1 → test2 → impl2 → test3 → impl3
```

Tests written in bulk test imagined behavior. Each test should respond to what you learned from the previous cycle.

## Workflow

### 1. Incremental Loop

Work through each stub in dependency order. For each behavior:

```
RED:   write next test → cargo test → fails
GREEN: minimal code to pass → cargo test → passes
```

Rules:

- One test at a time
- Only enough code to pass the current test — do not anticipate future tests
- Exhaustive match arms the current test doesn't reach: use `todo!()`, not `unreachable!()`
- Run the loop autonomously — stop only if something is surprising or unclear

### 2. Property Tests

After all example-based tests pass for a function, add property-based tests:

```
PROPERTY: write property test → cargo test → should pass
```

A property test going RED is a bug — the example tests missed a case. When that happens:

1. Write a minimal example test that reproduces the failure
2. Fix through the normal RED → GREEN cycle
3. Confirm the property test now passes

### 3. Refactor

After all tests pass, look for [refactor candidates](refactoring.md):

- [ ] Extract duplicated logic into a named free function
- [ ] Replace explicit `for` loops with iterator chains
- [ ] Remove unnecessary `mut` or `clone`
- [ ] Replace `unwrap()` in non-test code with proper error handling
- [ ] Check if any async function has crept in logic — small condition: extract as free function; significant algorithm: stop and re-invoke type-design
- [ ] Notice if nearby existing code has become obviously problematic next to the new code — fix it if so
- [ ] Run `cargo test` after each refactor step
- [ ] Run `cargo clippy` and address warnings

**Never refactor while RED.** Get to GREEN first.

## Checklist Per Cycle

```
[ ] Test name follows behavior_when_condition style
[ ] Test calls the function directly with inputs and checks the output
[ ] Test uses expect("reason") instead of unwrap()
[ ] Test would survive an internal refactor of the function body
[ ] Code is minimal for this test
[ ] Derives added freely; non-derived impls have a test first
[ ] No speculative code added
[ ] cargo test passes
```
