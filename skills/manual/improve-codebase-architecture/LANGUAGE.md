# Language

Vocabulary for every suggestion this skill makes. Use these terms — don't substitute "component," "service," "API," or "boundary."

For type-level patterns (newtypes, ADTs, sans-IO, pure core, effects as data), see:
- [`../../auto/type-design/rust-type-patterns.md`](../../auto/type-design/rust-type-patterns.md)
- [`../../auto/type-design/sans-io.md`](../../auto/type-design/sans-io.md)

## Depth in functional Rust

**Depth** is leverage at the interface — a lot of behaviour behind a small surface. In functional Rust, depth is achieved through types and function design, not class hierarchies.

### Deep types

A type is **deep** when its constructor hides significant logic and the rest of the codebase blindly trusts the result.

- **Make-invalid-states-unrepresentable enum**: `Connection { Disconnected, Connected { address: String } }` — two variants, zero bugs from accessing an address on a disconnected socket.
- **Parse boundary**: `Email::parse(raw)` — one entry point hides all validation logic. Once constructed, the type guarantees validity everywhere.

### Shallow types

A type is **shallow** when it costs syntactic friction without buying guarantees.

- **Unvalidated newtype**: `struct Email(String)` with no `parse()` — pays the wrapping/unwrapping cost everywhere, but guarantees nothing.
- **Data-heavy struct**: 20 public primitive fields the caller must manually validate and mutate.

### Deep functions

A function is **deep** when a small interface hides a large amount of behaviour.

- **Sans-IO core**: `fn handle(&mut self, now: Instant, event: Event) -> Outcome<Action, Publish>` — one entry point hides the entire state machine.
- **Smart constructor**: `TryFrom<&str> for Email` — one call hides all validation logic.

### Shallow abstractions

An abstraction is **shallow** when the interface is as complex as the implementation.

- **Premature trait**: a trait with only one implementer. The interface doubles the cognitive surface area with zero new behaviour or flexibility.
- **Orchestration boilerplate**: shell functions that each do one line before delegating — indirection without depth.

## Locality

What maintainers get from depth. Change, bugs, and knowledge concentrate at one place rather than spreading across callers. Fix once, fixed everywhere.

## The deletion test

Imagine deleting the abstraction. If complexity vanishes, it was a pass-through (shallow). If complexity reappears across callers, it was earning its keep (deep).

