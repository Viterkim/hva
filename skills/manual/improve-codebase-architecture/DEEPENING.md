# Deepening

How to test across boundaries in functional Rust. No mocking, no adapters, no injection.

## Two rules

### Testing the core

The pure core is a function: inputs in, outputs out. Test it by passing data and asserting on the result. Nothing to fake.

If the core needs data from the outside world, the shell fetches it and feeds it in as an `Event`. The core never touches I/O — so the test just passes the `Event` directly.

External services (Stripe, Twilio), internal services, and time (`Instant`) all become either `Action` variants (for outputs) or function arguments (for inputs like `now: Instant`). The test asserts that the correct `Action` was returned. No ports, no adapters, no injection.

```rust
#[test]
fn charge_action_returned_when_payment_due() {
    let mut core = Core::new(config(), now());
    let actions = core.handle(now(), Event::PaymentDue { amount: Money::eur(50) });
    assert!(actions.contains(&Action::ChargeStripe { amount: Money::eur(50) }));
}
```

### Testing the shell

The shell is async and logic-free — there is nothing to unit test. For integration coverage, run the shell and core together against a real local stand-in (e.g. PGLite for Postgres, a local SMTP server). These are coarse-grained integration tests, not part of the TDD cycle.

## Signal: shallow vs deep boundary

Apply the deletion test to any abstraction at a boundary:

- **Delete the trait.** If it has one implementer, it's a shallow abstraction. Complexity doesn't concentrate — it just costs surface area. Fix: use a concrete type or free function.
- **Keep the trait.** If two distinct implementations exist (or are imminent — production + a real alternative, not production + a mock), the trait is earning its keep.

The criterion is **two real adapters**, not "production plus a test fake." Mocks are not adapters.

