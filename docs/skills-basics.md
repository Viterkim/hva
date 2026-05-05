# Skills basics

- `--skill` makes Pi discover skills
- discovery is not full activation
- Pi starts with name + description only
- full `SKILL.md` matters only after activation
- weak local models often do not load it on their own
- `/skill:name` forces a manual skill load
- HVA keeps curated skills in `/hva-state/skills-active`
- every auto skill must be in one injection bucket: `HVA_SOFT_INJECT_SKILLS`, `HVA_HARD_INJECT_SKILLS`, or `HVA_DONT_INJECT_SKILLS`
- `HVA_SOFT_INJECT_SKILLS` adds a match hint only
- `HVA_HARD_INJECT_SKILLS` injects the full skill body. keep it empty unless you have a tested reason
- `HVA_SKIP_ALL_INJECTS=1` overrides both inject lists
- a skill can be in only one injection bucket
- everything else still uses `activate_skill`
- Pi docs: https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md
- Agent Skills guide: https://agentskills.io/client-implementation/adding-skills-support
