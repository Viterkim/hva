---
name: planner
description: Make a tracked plan.
disable-model-invocation: true
---

# Planner

Two files in the project root:

- `plan.md` - the steps, written before doing anything
- `knowns.md` - key findings you need to remember when context is gone, one line each, only niche stuff not obvious things

## Plan format

```markdown
# Plan: task name
- [ ] step one
- [ ] step two
- [x] done step
```

## Flow

Write `plan.md` first. Read `knowns.md` before each step. Do the step. Check it off. Add anything important to `knowns.md`. Repeat.

The point is to not lose things to context rot.
