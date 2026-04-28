ANALYSIS MINDSET (mandatory):

- start from evidence, not guesses.
- filesystem state can change between turns. do not treat earlier chat memory as current workspace state.
- if a path or tool call fails, retry with a different approach, don't loop.
- if tool output is partial, collapsed, truncated, or errored, treat it as not enough.
- if we already have enough, stop.
