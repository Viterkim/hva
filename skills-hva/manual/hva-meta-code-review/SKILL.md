---
name: hva-meta-code-review
description: "Review the HVA repo itself for changes: config, skills, CLI flags, docker, validation, mismatches."
disable-model-invocation: true
---

# HVA Meta Code Review

Go through each section that applies. Note yes/no and what you found. Skip sections that don't apply to the diff.

## New CLI flag

- In `completions/hva.bash` flags array?
- In `completions/hva.fish` completions?
- Takes a value? Handled in the `prev` case in both completion files?
- Help text in the `usage()` function in `scripts/hva`?

## New config key

- In `env-validate.sh` `ENV_CONFIG_KEYS`?
- In the right validation block in `env-validate.sh` (string, number, boolean, enum)?
- In `config/hva-conf.json.sample` with a sane default?
- Picked up and exported/used in `scripts/hva` (not silently ignored)?
- If it affects docker: passed through in `exec_args` or `docker_args`?
- If it affects the container runtime: available in `pi-runtime.sh` or other internals?

## New skill

- Auto/manual skill names are discovered from directories in `env-validate.sh`.
- Must appear in the matching auto/manual enabled or disabled config list.
- If manual skill: does it need a `/skill:name` entry in `readme.md`?
- If it references HVA-specific paths (`/hva`, `/hva-state`, `/workspace`), are those correct?
- Does HVA's skill activation path still load it properly, not just catalog it?
- If it is auto: does `activate_skill` expose it?
- If it is in `HVA_SOFT_INJECT_SKILLS` or `HVA_HARD_INJECT_SKILLS`, is that intentional and still correct?
- If it is injected, should it be soft instead of hard by default?
- If it is hard injected, is there a tested reason and result for that?

## New MCP

- In `KNOWN_MCP_KEYS` in `env-validate.sh`?
- In `KNOWN_MCP` in `pi/extensions/agent-guidance.ts`?
- Wired up in `pi/extensions/mcp-tools.ts`?
- Must appear in `HVA_MCP_ENABLED` or `HVA_MCP_DISABLED` in `config/hva-conf.json.sample`.

## New optional extension

- In `KNOWN_EXTENSION_KEYS` in `env-validate.sh`?
- Must appear in `HVA_EXTENSIONS_ENABLED` or `HVA_EXTENSIONS_DISABLED` in `config/hva-conf.json.sample`.
- Passed into the container in `scripts/hva`?
- Gated in `internals/pi-runtime.sh`, not always loaded?
- If it adds bundled skills too, are those gated with the extension?

## New mount or docker arg

- `HVA_MOUNT_*`: validated in `env-validate.sh`? Wired into `exec_args` in `scripts/hva`?
- New `--volume` or `--device`: added conditionally, not always-on?
- New env var passed into the container: added to `exec_args` with `-e`?
- If it requires something on the host, does `scripts/hva` check and warn?

## Enable/disable toggles

- Is the feature gated on its env var throughout — not just at startup?
- Does disabling it actually skip the thing, not just skip the warning?
- Does the config sample default match what a new user should get?
- For CSV enable/disable lists: every known entry listed exactly once, never in both.
- For skill injection: is every auto skill in exactly one of soft, hard, or dont-inject, and does `HVA_SKIP_ALL_INJECTS=1` override both inject lists?

## Value flow — trace a new value end to end

- `hva-conf.json` → `env-validate.sh` exports it → `scripts/hva` reads it → docker `-e` or volume → container sees it → runtime/pi uses it.
- Any gap in that chain means the value is silently dropped.

## General

- New workspace writes (temp files, state dirs) cleaned up in `cleanup()` in `scripts/hva`?
- `sync-config.sh` picks up new sample keys automatically — no changes needed there.
- Docs (`readme.md`, `docs/`) only need updating for things a user would configure or invoke directly.
- If skills changed, are `docs/skills-basics.md` and `docs/new-skill.md` still true?
