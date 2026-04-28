---
name: rust-style
description: "Use for rust files / rust programs. (.rs and related)"
---

# Basics

- format!("{v}") instead of format!("{}", v)
- import dependencies like 'tokio' at top, instead of tokio::fs, info!("{v}") instead of tracing::info!() etc
- don't suggest standard/alternative crates over the currently used crates
- if you lack context/info/simply a little uncertain about a crate, ALWAYS search for it via 'rust-docs' for for understanding + examples
- also use the workspace repo itself for relevant examples
- prefer versioning crates with "x.y", so: "1.1", not "1" and not "1.1.2"
- preferable new crates, only when adding crates:

```
general: async/tokio (https://docs.rs/tokio/latest/tokio/) (async)
error handling: exn (https://docs.rs/exn/latest/exn/) (.or_raise(||))
time: jiff (https://docs.rs/jiff/latest/jiff/) (Timestamp + Zoned)
cli/conf: conf-rs (https://docs.rs/conf/latest/conf/) (::try_parse_from())

```

- AVOID adding these crates (fine if the project already uses them):

```
NO:
error handling: thiserror/anyhow
time: chrono
cli/conf: clap
```

- when making a new crate use a lib structure with a bin/main.rs (don't just make a cargo.toml, actually create the structure, get the newest tokio)
