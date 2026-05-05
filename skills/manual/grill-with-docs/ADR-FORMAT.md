# ADR Format

ADRs live in `docs/adr/` and use sequential numbering: `0001-slug.md`, `0002-slug.md`, etc.

Create the `docs/adr/` directory lazily — only when the first ADR is needed.

## Template

```md
# {Short title of the decision}

{1-3 sentences: what's the context, what did we decide, and why.}
```

That's it. An ADR can be a single paragraph. The value is in recording _that_ a decision was made and _why_ — not in filling out sections.

## Optional sections

Only include these when they add genuine value. Most ADRs won't need them.

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`) — useful when decisions are revisited
- **Considered Options** — only when the rejected alternatives are worth remembering
- **Consequences** — only when non-obvious downstream effects need to be called out

## Numbering

Scan `docs/adr/` for the highest existing number and increment by one.

## When to offer an ADR

All three of these must be true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will look at the code and wonder "why on earth did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If a decision is easy to reverse, skip it — you'll just reverse it. If it's not surprising, nobody will wonder why. If there was no real alternative, there's nothing to record beyond "we did the obvious thing."

### What qualifies

- **Architectural shape.** "We are using a single, unified Core state machine instead of splitting it into multiple domain-specific Cores, because the cross-domain transactions require atomic state transitions."
- **Integration patterns across the I/O boundary.** "The Shell communicates with the external Billing service by emitting a fire-and-forget `Action::PublishBillingEvent` rather than waiting for an `Event::BillingConfirmed` to prevent blocking the state machine."
- **Technology choices that carry lock-in.** Decisions regarding the async runtime (e.g., `tokio` vs `async-std`), embedded HALs, database drivers, or serialization formats. Not every crate — just the ones that would take a quarter to swap out.
- **Boundary and scope decisions.** "The `Event` enum will only accept pre-parsed, validated domain Newtypes. The async Shell is responsible for handling all raw parsing errors before an Event is even constructed." The explicit no-s are as valuable as the yes-s.
- **Deliberate deviations from the obvious path.** "We are keeping the `HardwareGateway` trait and using dependency injection in the Shell instead of purely relying on `Action` enums, because the firmware team needs to swap the adapter out at runtime based on the detected board revision." Anything where a reasonable reader would assume the pure functional opposite.
- **Constraints not visible in the code.** "We are using `Arc<T>` here instead of just cloning the data structure because the memory footprint of this specific tree exceeds the embedded device's RAM limits."
- **Rejected alternatives when the rejection is non-obvious.** If you considered using a global `Mutex` for shared state but picked a pure Sans-IO core instead for strict testability reasons, record it — otherwise someone will suggest adding an `RwLock` again in six months.
