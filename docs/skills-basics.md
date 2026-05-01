# Skills basics

- `--skill` makes Pi discover skills
- discovery is not full activation
- Pi starts with name + description only
- full `SKILL.md` matters only after activation
- weak local models often do not load it on their own
- `/skill:name` forces a manual skill load
- HVA keeps curated skills in `/hva-state/skills-active`
- `HVA_SOFT_INJECT_SKILLS` adds a match hint only and is the normal default
- `HVA_HARD_INJECT_SKILLS` injects the full skill body. keep it empty unless you have a tested reason
- `HVA_SKIP_INJECT=1` disables both inject lists
- a skill can be in soft or hard, not both
- everything else still uses `activate_skill`
- Pi docs: https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md
- Agent Skills guide: https://agentskills.io/client-implementation/adding-skills-support
