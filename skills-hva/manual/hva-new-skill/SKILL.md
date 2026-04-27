---
name: hva-new-skill
description: Make or change HVA skills.
disable-model-invocation: true
---

# New Skill

This assumes the workspace is the HVA repo.

If the workspace does not have `scripts/hva`, `skills`, and `pi/extensions`, say the workspace is not the HVA project and stop.

Pick the right tier:

- Needs to run every turn: extension in `pi/extensions/`
- Prompt-only HVA runtime guidance: markdown in `hva-runtime/`, injected from `pi/extensions/agent-guidance.ts`
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

There is no `skills/always`. Always-on runtime guidance lives in `hva-runtime/`.

If you add, remove, or rename a manual skill, update the skill lists in `pi/extensions/agent-guidance.ts` too.

## Creating an extension

Add the `.ts` file to `pi/extensions/`, add it to the copy list in `hva_ensure_pi_extension_deps` in `internals/pi-runtime.sh`, and add `--extension "$ext_dir/my-extension.ts"` to `hva_pi_base_args`.
