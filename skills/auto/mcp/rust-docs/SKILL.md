---
name: rust-docs
description: "Looks up Rust crate docs, API, usage patterns, versions, features, and examples from crates.io and docs.rs. Use when asked how any crate works, what its API is, what version to use, or before writing code that uses a crate."
---

# Rust Docs

Use the Rust MCP tools. Always look up before answering.

- `crates_package_info` — versions and metadata
- `crates_search` — finding crates by keyword
- `crates_dependencies` — dependency trees
- `docs_rs_read` — API, usage, examples, feature flags

**Never describe how a crate works without reading the docs first.**
**Never infer API from crate name, a hint in another skill, or a similar crate.**
**Never guess versions.**

For any "how does X work?" or "how do I use X?" question: run `docs_rs_read` first, then answer from what you actually read.
