---
name: hva-new-skill
description: "Make or change HVA skills."
disable-model-invocation: true
---

# New Skill

This assumes the workspace is the HVA repo.

If the workspace does not have `scripts/hva`, `skills`, and `pi/extensions`, say the workspace is not the HVA project and stop.

Pick the right tier:

- Needs to run every turn: extension in `pi/extensions/`
- Prompt-only HVA runtime guidance: `hva-runtime/global.md`, injected from `pi/extensions/agent-guidance.ts`
- Context relevant, LLM decides when to use it: normal skill in `skills/`
- Only when explicitly asked: skill with `disable-model-invocation: true`

## Naming

Generic skills use plain names. HVA specific ones use the `hva-` prefix.

## Creating a skill

Use these folders:

- generic auto skill: `skills/auto/my-skill/SKILL.md`
- generic manual skill: `skills/manual/my-skill/SKILL.md`
- HVA auto skill: `skills-hva/auto/my-skill/SKILL.md`
- HVA manual skill: `skills-hva/manual/my-skill/SKILL.md`

In skill frontmatter, quote the whole `description` value.

## Description format

The description is the only thing Pi sees when deciding whether to load the skill. Make it count.

- First sentence: what the skill does.
- Second sentence: `Use when [specific triggers].`
- Max 1024 chars. Be specific — vague descriptions get skipped.

Good:

```
"Shell script style and safety rules. Use when writing, editing, or reviewing bash or shell scripts."
```

Bad:

```
"Helps with shell stuff."
```

## How skills actually work here

Read `docs/skills-basics.md` first.

- `--skill` or normal discovery makes Pi catalog the skill
- that does not mean the full `SKILL.md` is loaded yet
- Pi starts with name + description only
- full instructions matter only after activation
- weak local models often do not load skills reliably on their own
- `/skill:name` is the manual force path
- `HVA_SOFT_INJECT_SKILLS` adds a match hint only
- `HVA_HARD_INJECT_SKILLS` injects the full skill body. use it only if there is a tested reason
- `HVA_DONT_INJECT_SKILLS` explicitly keeps an auto skill out of prompt injection
- `HVA_SKIP_ALL_INJECTS=1` disables both inject lists
- do not put the same skill in more than one injection list
- other auto skills should load through `activate_skill`

## SKILL.md size

Keep SKILL.md under ~200 lines. If it grows, split:

- `REFERENCE.md` — detailed reference, rarely needed
- `EXAMPLES.md` — usage examples
- `scripts/` — helper scripts for deterministic operations (validation, formatting, diffing)

Prefer scripts over generated code — they save tokens and behave consistently.

## No time-sensitive content

Don't hardcode versions, dates, or anything that will rot. Use tools (rust-docs, npm-search, pypi) to look up current values at runtime.

## After creating or renaming

- Add auto skills to `HVA_AUTO_SKILLS_ENABLED` or `HVA_AUTO_SKILLS_DISABLED`.
- Add manual skills to `HVA_MANUAL_SKILLS_ENABLED` or `HVA_MANUAL_SKILLS_DISABLED`.
- If manual skill: add `/skill:name` entry to `readme.md`.
- If you add, remove, or rename a manual skill, check `pi/extensions/agent-guidance.ts` too.
- Put each auto skill in exactly one of `HVA_SOFT_INJECT_SKILLS`, `HVA_HARD_INJECT_SKILLS`, or `HVA_DONT_INJECT_SKILLS`.
- Only use `HVA_HARD_INJECT_SKILLS` if you tested that soft is not enough and hard really helps.
- If you want to compare behavior with injection fully off, set `HVA_SKIP_ALL_INJECTS=1`.

## Creating an extension

Add the `.ts` file to `pi/extensions/`, add it to the copy list in `hva_ensure_pi_extension_deps` in `internals/pi-runtime.sh`, and add `--extension "$ext_dir/my-extension.ts"` to `hva_pi_base_args`.

If it is optional:

- add its name to `KNOWN_EXTENSION_KEYS` in `env-validate.sh`
- list it in `HVA_EXTENSIONS_ENABLED` or `HVA_EXTENSIONS_DISABLED` in `config/hva-conf.json.sample`
- pass those config keys into the container in `scripts/hva`
- gate both the extension and any bundled skills in `internals/pi-runtime.sh`

References:

- `docs/skills-basics.md`
- https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md
