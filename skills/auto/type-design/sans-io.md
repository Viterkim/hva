# Sans-IO Machines

A sans-IO machine splits a service into two parts:

- **Core** — a pure state machine. All logic lives here. No I/O, no `async`, no side effects.
- **Shell** — dumb orchestration. Executes the actions the core returns. No logic, no state.

```
Event
  │
  ▼
┌─────────────────────────────┐
│  Core (pure, sync)          │
│  State + handle(now, event) │──► Vec<Action>  ──► Shell executes
│                             │──► Vec<Publish> ──► Shell broadcasts (optional)
└─────────────────────────────┘
```

**When to use this pattern:** if a component holds mutable state and reacts to events, reach for the sans-IO split.

## Core rules

**Core:**
- Always sync — never `async`
- Takes `now: Instant` as a parameter — never calls `Instant::now()` internally
- Returns `Vec<Action>` describing what should happen — does not do it
- All logic lives here — state transitions, decisions, sequencing

**Shell:**
- Always async
- Executes actions, no more, no less
- Contains no logic and no state
- If anything needs to be reasoned about, it goes back to the core as an event

If multiple actions are returned, the shell runs them in parallel. If ordering matters, an action completes and feeds a result back as a new event — the core then decides what happens next.

## Shape

The minimal shape returns only `Vec<Action>`. Add `Outcome<A, P>` and a `publish` field only when the component needs to broadcast state to other parts of the system via pubsub.

```rust
// Minimal — no pubsub needed
fn handle(&mut self, now: Instant, event: Event) -> Vec<Action> {
    todo!("apply event to state, return actions describing required side effects")
}
```

```rust
// With pubsub — only when broadcasting is needed
struct Outcome<A, P> {
    pub actions: Vec<A>,
    pub publish: Vec<P>,
}

fn handle(&mut self, now: Instant, event: Event) -> Outcome<Action, Publish> {
    todo!("apply event to state, return actions and any state updates to broadcast")
}
```

Full example:

```rust
enum Event {
    Init,
    HardwareStateChanged(HardwareStatus),
    TimerExpired(TimerId),
}

enum Action {
    StartTimer { id: TimerId, duration: Duration },
    CancelTimer(TimerId),
    PowerDownModem,
}

// Shell — async, no logic
async fn run_action(action: Action) {
    match action {
        Action::StartTimer { id, duration } => { /* start a tokio timer */ }
        Action::PowerDownModem => { /* write to hardware */ }
        // ...
    }
}
```

## Testing

Because the core is pure, testing is just: call `handle()`, assert on the returned actions. Nothing to mock, nothing to fake.

```rust
#[test]
fn nep_timer_starts_when_external_power_lost() {
    let mut core = Core::new(config(), now());
    let actions = core.handle(now(), Event::ExternalPowerLost);
    assert!(actions.contains(&Action::StartTimer {
        id: TimerId::NepExternalPowerLoss,
        duration: config().nep_external_loss_delay,
    }));
}

#[test]
fn nep_timer_cancelled_when_power_restored() {
    let mut core = Core::new(config(), now());
    core.handle(now(), Event::ExternalPowerLost);
    let actions = core.handle(now(), Event::ExternalPowerRestored);
    assert!(actions.contains(&Action::CancelTimer(TimerId::NepExternalPowerLoss)));
}
```

Multi-step sequences are tested by calling `handle()` multiple times — the state carries forward naturally:

```rust
#[test]
fn reboot_becomes_imminent_before_deadline() {
    let mut core = Core::new(config(), now());
    core.handle(now(), Event::RebootScheduled { deadline: now() + Duration::from_secs(60) });
    let Outcome { publish, .. } = core.handle(now() + Duration::from_secs(45), Event::TimerExpired(TimerId::RebootScheduled));
    assert!(publish.contains(&Publish::Reboot(ActionPhaseMsg { phase: ActionPhaseName::Imminent, .. })));
}
```

The shell is async and logic-free — it is not unit tested. Integration tests or manual verification cover it if needed.

## Splitting and composition

A handful of `_ => vec![]` catch-alls is normal — do not split for purity alone. The real threshold is cognitive overload: a maintainer can no longer hold the state machine's full transition table in their head, or adding an unrelated feature requires touching the core. Premature splitting destroys the locality that makes the sans-IO pattern valuable.

### Phase 1 — Deepen the shape first

Before splitting, try fixing the internal state structure.

**Symptom:** cartesian state explosion — variants like `ConnectedAndDownloading`, `DisconnectedAndDownloading`, `ConnectedAndIdle` multiply as unrelated concerns combine into a single enum.

**Fix:** replace the flat top-level enum with a struct holding independent enums:

```rust
struct AppCore {
    session_id: SessionId,    // permanent — not part of any transition
    network: NetworkState,    // enum: Connected / Disconnected
    download: DownloadState,  // enum: Idle / Active
}
```

Match `self.network` and `self.download` independently in `handle()`. The explosion disappears without splitting the core or introducing routing overhead.

### Phase 2 — Split the core

If the shape is already sound and the core is still unwieldy, split it. The split type follows from one question: **does one core own the lifecycle of the other?**

**Hierarchical** — Core A creates, resets, or destroys Core B. Core A holds Core B as a field, delegates relevant events to `self.child.handle()`, and maps the returned child `Action`s into its own `Action` type. The shell only talks to Core A.

**Orthogonal** — the cores simply coexist independently. Move event routing to the shell. Each core only ever sees events it cares about.

**Matching symptoms to strategies:**

*Catch-all abuse or meaningless events* — a core is forced to consume `Event::NetworkRestored` or `Event::Tick` even though 90% of its states don't care.
→ **Orthogonal.** The shell routes; each core receives only its own events.

*Action disjointness* — `handle()` can return both `Action::BlinkLed` and `Action::ProcessCreditCard`, spanning entirely separate bounded contexts.
→ **Apply the lifecycle heuristic.** If one context's lifecycle drives the other (e.g. hardware must initialise before billing is possible), use Hierarchical. If they are independent, use Orthogonal.
