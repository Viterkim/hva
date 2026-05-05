---
name: rust-style
description: "Rust coding style and preferred crate rules. Use when creating, editing, or working with any Rust code or Rust project."
---

# Basics

- no inline comments
- `format!("{v}")` not `format!("{}", v)`
- import at the top level — `use tokio::fs` not inline `tokio::fs::`, `info!("{v}")` not `tracing::info!()`
- don't suggest alternative crates over what the project already uses
- any uncertainty about a crate's API or usage: stop, use rust-docs to look it up — no guessing, no inferring from the crate name
- use the workspace repo for relevant usage examples
- version crates with "x.y": `"1.1"` not `"1"` or `"1.1.2"`

## Preferred crates (new deps only)

No API hints here — look everything up via rust-docs before writing any code.

```
async:          tokio
error handling: exn
time:           jiff
cli/conf:       conf-rs
```

## Avoid (fine if already in project)

```
error handling: thiserror, anyhow
time:           chrono
cli/conf:       clap
```

## New crate structure

Use lib layout. Create manually — do not use `cargo init` which makes a plain binary:

```
bingo/
  Cargo.toml
  src/
    lib.rs
    bin/
      main.rs
```

Get the current tokio version via rust-docs before writing the Cargo.toml.

## Finish flow

After a full Rust edit pass is done, do this before you stop:

1. run `cargo check`
2. if it fails, fix it and rerun `cargo check` until it passes
3. then run `cargo clippy`
4. if it fails, fix it and rerun `cargo clippy` until it passes
5. when both pass, run `cargo fmt`

Do not stop after writing Rust code without doing that flow.
