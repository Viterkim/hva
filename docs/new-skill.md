# Adding a skill or extension

See [skills-basics.md](skills-basics.md) for how skills actually work in Pi and HVA.

- Skill: `SKILL.md` file. Listed in catalog, LLM reads it on demand or you load it with `/skill:name`
- Extension: TypeScript. Hooks into Pi lifecycle, registers tools or commands.

## Skills

Create a directory under `skills/`:

```
skills/auto/my-skill/SKILL.md
```

```markdown
---
name: my-skill
description: "Use when doing X."
---

Instructions here.
```

To make it manual only (hidden from LLM, load with `/skill:my-skill`):

```markdown
---
name: my-skill
description: "Does X."
disable-model-invocation: true
---
```

Quote skill `description` values in frontmatter.

This avoids YAML breaking when the text contains `:` or similar punctuation.

HVA-specific skills live under `skills-hva/`.

## Injection defaults

- Put each auto skill in exactly one injection bucket: `HVA_SOFT_INJECT_SKILLS`, `HVA_HARD_INJECT_SKILLS`, or `HVA_DONT_INJECT_SKILLS`
- Use `HVA_HARD_INJECT_SKILLS` only if you tested it and soft is not enough
- Use `HVA_SKIP_ALL_INJECTS=1` to compare against no injection

## Extensions

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event) => {
    return { systemPrompt: event.systemPrompt + "\nExtra context." };
  });
  pi.registerCommand("my-command", {
    description: "Does something",
    handler: async (args, ctx) => {
      ctx.ui.notify("hi", "info");
    },
  });
}
```

Other events: `session_start`, `session_shutdown`, `turn_end`. Full list in `node_modules/@mariozechner/pi-coding-agent/dist/core/extensions/types.d.ts`.

Wire it up in `internals/pi-runtime.sh` in `hva_pi_base_args` and add the file to the copy list in `hva_ensure_pi_extension_deps`.

## Example

`skills-hva/manual/hva-meta-code-review/SKILL.md` has `disable-model-invocation: true` so it's invisible during normal sessions. Type `/skill:hva-meta-code-review` when reviewing a PR to this repo.
