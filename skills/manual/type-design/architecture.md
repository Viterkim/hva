## Module and Crate Boundaries

Decide where types live and how they are exposed. Module and crate layout is an architectural interface decision, not an implementation detail.

**Workspace Layout**
Follow the standard Cargo workspace pattern. The top-level `src/` directory is strictly for the main application or primary crate. Auxiliary libraries, domain extractions, and standalone utilities belong in the `crates/` directory as separate Cargo packages.

**When to make a new crate (in `crates/`)**
Default to modules within the main crate. Only reach for a new crate when you need:

1. **Strict dependency isolation** — e.g., structurally preventing the core domain from accidentally importing database or web framework types.
2. **Distinct compilation units** — procedural macros (which _must_ be their own crate) or heavily reused code to leverage `cargo` caching.
3. **Universal reuse** — utility crates (`crates/telemetry`, `crates/test_utils`) shared across multiple binaries.

**Creating a new crate**

When a new crate in `crates/` is approved, before writing any types:

1. Create `crates/<name>/src/lib.rs` (empty).
2. Write `crates/<name>/Cargo.toml` with name, version, and edition.
3. Add the crate to the `members` array in the root `Cargo.toml`.
4. If the new crate is consumed by another package in the workspace, add it as a path dependency there.
5. Run `cargo check --workspace` to confirm the workspace compiles before proceeding.

**The Facade Pattern (`mod.rs` / `module.rs`)**
Module roots define the public interface of that module, while the internal file structure remains entirely private.

- **Strict Rule:** A `mod.rs` or `module.rs` file must **only** contain module declarations (`mod private_file;`) and exports (`pub use private_file::DomainType;`). This keeps the internal file layout invisible to consumers — internals can be reorganised freely without breaking callers.
- Absolutely **no** type definitions, traits, functions, or logic may live in a module root file.
- Consumers of the module must not need to know your internal file structure. They should interact purely with what is exported at the module root.

**Visibility Rules**
Assign intentional visibility to every type and function:

- `pub`: Only for types crossing the crate boundary or forming the explicit public API of a top-level module.
- `pub(crate)` / `pub(super)`: For types shared across internal module boundaries. This prevents accidental leaks to the public API while allowing internal composition.
- **Private (default):** For internal state, helpers, and data structures.

**No Circular Dependencies**
Circular dependencies between modules (or crates) are explicitly forbidden. If Module A depends on Module B, Module B cannot depend on Module A. If a cycle emerges during type-design, stop. It indicates a fundamental flaw in the domain boundaries. Fix the architecture by extracting the shared concept into a third module, or rethinking the domain model entirely, before proceeding.
