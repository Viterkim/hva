# Tests

## Test naming

Test names follow `behavior_when_condition`:

```rust
#[test]
fn discount_applied_when_cart_exceeds_threshold() { ... }

#[test]
fn no_discount_when_cart_below_threshold() { ... }
```

The name describes **what** happens, not **how** the code does it.

## Test fixtures

Shared setup lives in small pure builder functions defined once in the test module. Name them after what they represent, not how they are used:

```rust
#[cfg(test)]
mod tests {
    fn default_config() -> Config { ... }
    fn now() -> Instant { Instant::now() }
}
```

Comment non-obvious choices — e.g. why a specific edge-case value was chosen. Everything else should be self-explanatory from the name and the assertion.

## Free functions and &self methods

Testing is identical: call with inputs, assert on the output.

```rust
#[test]
fn discount_applied_when_cart_exceeds_threshold() {
    let result = apply_discount(Money::eur(150), &threshold_rules());
    assert_eq!(result, Money::eur(135));
}
```

No mocks, no fakes, no setup beyond constructing the inputs. 100% branch coverage is required.

## Sans-IO machines

The core returns `Vec<Action>`. Assert on the returned actions — there are no side effects to verify and nothing to mock.

```rust
#[test]
fn nep_timer_starts_when_external_power_lost() {
    let mut core = Core::new(default_config(), now());
    let actions = core.handle(now(), Event::ExternalPowerLost);
    assert!(actions.contains(&Action::StartTimer {
        id: TimerId::Nep,
        duration: default_config().nep_delay,
    }));
}
```

Multi-step sequences call `handle()` multiple times — state carries forward naturally.

## Async functions

Async functions contain no logic — they are orchestration only. There is nothing to unit test. Integration tests or manual verification cover them if needed.

## Property tests

After all example-based tests pass for a function, write property-based tests to probe the full input space. A property test going RED is a bug — write a minimal example test reproducing the failure, fix it through the normal cycle, then confirm the property test passes.

## `expect` over `unwrap`

Use `expect("reason")` instead of `unwrap()` in tests. The message appears in the failure output and explains why the value was expected to exist.

## What makes a bad test

- Asserting on internal state rather than the return value
- A test that breaks when the function body is refactored but behavior hasn't changed
- A test name that describes HOW not WHAT (`test_calls_calculate_discount` vs `discount_applied_above_threshold`)
- `unwrap()` without a message — use `expect("reason")` instead

