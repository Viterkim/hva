# Skill Basics

## Three tiers

### Extensions

TypeScript, hooked into `before_agent_start`. Runs every turn, no LLM involved.

- `pi/extensions/agent-guidance.ts` + `hva-runtime/runtime.md` (response style + injected HVA runtime)

### Skills

Pi injects a catalog at session start with just name + description (~50 tokens each). LLM reads the full `SKILL.md` via the `read` tool when the task matches.

Quote skill `description` values in frontmatter.

- `skills/auto/documentation` and `skills/auto/review` (normal context-loaded skills)

### Manual skills

Add `disable-model-invocation: true` to frontmatter. Hidden from the catalog, LLM never sees it. User loads it with `/skill:name`.

- `skills-hva/manual/hva-meta-code-review` (chunky checklist, only when reviewing an HVA PR)

20 skills loaded = ~1000 tokens for the catalog. Full skill body only read on demand.

## Other agents

|                     | always on                      | auto                      | manual                           |
| ------------------- | ------------------------------ | ------------------------- | -------------------------------- |
| Pi                  | extension `before_agent_start` | skill catalog + LLM reads | `disable-model-invocation: true` |
| Cursor              | rule always                    | rule auto-attach          | rule manual                      |
| Claude Code / Codex | `CLAUDE.md` / `AGENTS.md`      | n/a                       | n/a                              |

Cursor's auto-attach fires on file patterns. Pi doesn't have that natively but a `resources_discover` extension can do it.
