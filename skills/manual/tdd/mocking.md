# No Mocking

Mocking is not used. The code is designed so it is never needed:

- **Pure functions** take inputs and return outputs. Nothing to mock — just call them.
- **Async functions** are kept logic-free, so there is nothing complex to test.
- **Sans-IO machines** return `Vec<Action>`. Assert on the actions directly.

If you feel the urge to mock something, that is a signal the design needs fixing:

| Urge | Actual problem | Fix |
|---|---|---|
| Mock a database call | Logic and I/O are mixed | Extract the logic into a pure function, test that |
| Mock an internal function | You are testing implementation, not behavior | Test the outer function instead |
| Mock time | `Instant::now()` called internally | Pass `now: Instant` as a parameter |
| Mock a dependency | Async code contains logic | Move the logic into a sync pure function |


