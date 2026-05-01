# Rust Type Patterns

Reference for the type-design session. These are the patterns to apply and the anti-patterns to call out.

## Types in detail

### Derives

Add common derives during type-design: `Debug`, `Clone`, `PartialEq`, `Eq`, and `Hash` where they apply. `Hash` must accompany `Eq` for any type used as a map key. If a type must not be cloned freely, omit `Clone` intentionally and note why.

### Visibility

Decide visibility (`pub`, `pub(crate)`, or private) for every type and function as part of this session. Visibility is an interface decision, not an implementation detail.

### Newtypes and conversion traits

For newtypes, design the full interface here:

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

Prefer `thiserror` for domain error enums unless the project already uses a different established error pattern. Design the domain-level failure variants here. TDD may add variants for external crate errors (`#[from]` attributes couple to implementation details and are decided at TDD time, not here).

```rust
#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("token is expired")]
    Expired,
    #[error("token signature is invalid")]
    InvalidSignature,
    // TDD will add: #[from] variants for JWT library errors
}
```

## Newtypes

Wrap raw primitives in named types at domain boundaries. Two reasons — both matter:

1. **Type safety** — the compiler rejects passing `ManufacturerId` where `PartId` is expected
2. **Documentation** — `ClientTxId` is self-explaining in a way `Uuid` is not. If something has a name, give it a type with that name.

```rust
// Anti-pattern: raw primitives
fn get_part(id: i64) -> Part { todo!() }

// Good: named types
struct PartId(i64);
fn get_part(id: PartId) -> Part { todo!() }
```

Signal: if you find yourself writing a comment to explain what a field means, that field needs a type name instead.

### Newtype conversion traits

Design these during type-design — they are part of the interface.

#### 1. Construction (Getting data in)

Use standard traits so callers get idiomatic Rust construction:

- `From<Inner>` — if construction is always valid (infallible)
- `TryFrom<Inner>` — if construction can fail (validation, parsing). Define the domain `Error` enum alongside it.

```rust
// Infallible wrapping
impl From<Uuid> for UserId {
    fn from(id: Uuid) -> Self { todo!() }
}

// Validated construction — define the error enum here too
impl TryFrom<&str> for Email {
    type Error = EmailError;
    fn try_from(raw: &str) -> Result<Self, Self::Error> { todo!("validate format, reject if not a valid email address") }
}
```

#### 2. Strict Encapsulation (Inside the system)

Default to strict encapsulation. The core system must operate on the domain types, not their underlying primitives.

Do **not** provide `.as_ref()`, `.into()`, or public access to the inner primitive for use within the core domain.

If a component needs to act on the data, implement that behaviour on the domain type itself:

```rust
// Anti-pattern: leaking the primitive into the core
fn process(email: &Email) {
    let raw: &str = email.as_ref(); // now the core depends on String
    let domain = raw.split('@').nth(1);
}

// Good: behaviour lives on the type
impl Email {
    pub fn domain(&self) -> &str { todo!() }
}
fn process(email: &Email) {
    let domain = email.domain();
}
```

Use `derive_more` carefully: it is encouraged for domain-meaningful traits (`Sum`, `Add`, `Display`) to reduce boilerplate, but **do not** derive `AsRef`, `Deref`, or `Into` unless explicitly required for a boundary. `Deref` to a primitive is an anti-pattern.

#### 3. Explicit Accessors (Crossing boundaries)

When a domain type must cross an outer system boundary (database writes, serialisation, third-party API calls), use explicit accessor methods:

```rust
pub fn into_inner(self) -> String { todo!() }
pub fn as_str(&self) -> &str { todo!() }
```

These are intentionally verbose. They act as highly visible, searchable signals that type safety is being intentionally dropped to interface with the outside world.

#### Use `nutype` for validated newtypes

When a newtype requires **simple structural validation** (bounds, string length, regex), prefer the `nutype` crate over manual `TryFrom` boilerplate. It generates the standard conversion traits while strictly hiding the inner primitive — the type boundary cannot be bypassed.

Use a manual `TryFrom` or `parse()` method when validation requires **external context** — for example, checking uniqueness against a database, or resolving against configuration that is not available at construction time.

```rust
use nutype::nutype;

#[nutype(validate(not_empty, max_len = 255))]
#[derive(Clone, Debug, PartialEq)]
pub struct Username(String);

// The macro automatically generates:
// - Username::new(raw) -> Result<Username, UsernameError>
// - TryFrom<String> for Username
// It deliberately does NOT generate Deref or DerefMut.
```

`Display`, `Serialize`, `Deserialize`, and similar are implementation details — leave them for TDD.

## Make invalid states unrepresentable

Design types so that invalid combinations cannot be constructed. If a combination of fields can be invalid, that's a design smell — encode the constraint in the type system.

```rust
// Anti-pattern: fields that must be consistent but nothing enforces it
struct Connection {
    connected: bool,
    address: Option<String>, // only meaningful when connected
}

// Good: states as an enum
enum Connection {
    Disconnected,
    Connected { address: String },
}
```

Ask for every struct: "Is there a combination of these fields that would be invalid?" If yes, reach for an enum.

## No sentinel values

Never use `0`, `-1`, empty string, or other magic values to signal absence or error.

```rust
// Anti-pattern
struct Config {
    timeout_ms: i64, // -1 means "no timeout"
}

// Good
struct Config {
    timeout: Option<Duration>,
}
```

## No `#[derive(Default)]` on validated types

Do not derive `Default` on validated newtypes, state machines, or any type where a zero/empty value would violate domain constraints.

```rust
// Anti-pattern: a zero UserId is not a valid domain object
#[derive(Default)]
struct UserId(i64);

// Good: construction is the only entry point
struct UserId(i64);
impl TryFrom<i64> for UserId {
    type Error = UserIdError;
    fn try_from(id: i64) -> Result<Self, Self::Error> { todo!("reject non-positive ids") }
}
```

`Default` is permitted on plain configuration structs or builder types where an empty/zero state is explicitly valid by domain definition.

## Parse at the boundary

All input is parsed into typed domain objects as early as possible at the outermost boundary. Invalid data never travels inward. Types should make it impossible to hold unvalidated data — construction is validation.

```rust
// Anti-pattern: validation separate from construction, caller must remember
struct Email(String);

// Good: construction enforces validity — use nutype (preferred) or TryFrom
#[nutype(validate(regex = r"^[^@]+@[^@]+$"))]
#[derive(Clone, Debug, PartialEq)]
pub struct Email(String);

// Or, when nutype is not appropriate:
impl TryFrom<&str> for Email {
    type Error = EmailError;
    fn try_from(raw: &str) -> Result<Self, Self::Error> { todo!("validate email format") }
}
// An Email can only exist if it was valid — impossible to construct an invalid one
```

## `async` marks side effects

Pure functions are never `async`. `async` is a signal that a function touches the outside world.

```rust
// Pure logic — sync
fn calculate_discount(cart: &Cart, rules: &DiscountRules) -> Discount { todo!() }

// Side effect — async
async fn fetch_cart(id: CartId) -> Result<Cart, DbError> { todo!() }
```

If a function is `async` and contains logic, split them: pure logic in a sync function, an async shell that calls it. Orchestration functions are the exception — they compose other functions and may contain a top-level `if` or `match` to decide which side effect to invoke next, but no nested branching, loops, or domain logic.

## Logic and side effects separated

Functions do one thing. Orchestration functions compose other functions — that is their only job, they contain no logic themselves. Logic functions are pure.

```rust
// Anti-pattern: logic and side effect mixed
async fn process_order(id: OrderId) -> Result<(), Error> {
    let order = fetch_order(id).await?;          // side effect
    let total = order.items.iter().sum();         // logic mixed in
    if total > 1000 { send_alert().await?; }     // more mixed concerns
    todo!()
}

// Good: separated
fn should_alert(order: &Order) -> bool { todo!() }  // pure logic

async fn process_order(id: OrderId) -> Result<(), Error> {  // orchestration only
    let order = fetch_order(id).await?;
    if should_alert(&order) {
        send_alert().await?;
    }
    todo!()
}
```

## Actions as data (sans-IO)

For stateful systems, the core returns descriptions of what should happen — not the result of doing it. The shell executes the actions. See [sans-io.md](sans-io.md) for shape, examples, and testing patterns.

## `Mutex` is a design smell

If you reach for `Mutex`, stop. It means ownership of that data was unclear at design time. Clarify which component owns the data and let Rust's ownership model enforce it.

## Data plain, behaviour separate

Structs hold data. Functions (or `impl` blocks with `&self` / `&mut self`) handle behaviour. No mixed-concern objects. `&mut` outside of `&mut self` is a warning sign — flag it on every occurrence, not only in cases of obvious shared state. Pure functions take values or shared refs and return new values.

## Lifetime parameters

Default to owned types. Reach for lifetime parameters only when:

1. The type is a deliberate view into a longer-lived allocation (e.g., a parsed frame backed by a byte slice).
2. Cloning the data would be measurably prohibitive and a borrow is architecturally sound.

When lifetimes appear, document which allocation is being borrowed from. Use `Arc<T>` when ownership truly must be shared across tasks or components — not as a general substitute for borrowing.
