# Refactor Candidates

After the TDD cycle, look for:

- **Duplication** → extract a named free function
- **Explicit `for` loops** → prefer iterator chains
- **Long functions** → break into smaller free functions
- **Unnecessary `mut`** → if a value is only mutated once before being returned, it can often be constructed directly
- **Unnecessary `clone()`** → reconsider ownership; cloning to paper over a borrow issue is a smell
- **`unwrap()` in non-test code** → replace with proper `Result` propagation
- **Mixed logic and orchestration** → if a function both does logic and calls other functions, split them. Small condition: extract as a free function. Significant algorithm: stop and re-invoke type-design.
- **`&self` method doing pure logic** → consider extracting as a free function taking the data as a parameter
- **Existing code** the new code reveals as problematic nearby
- **`cargo clippy` warnings** → address all of them
