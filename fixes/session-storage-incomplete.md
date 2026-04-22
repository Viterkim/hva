# Bug: thinking tokens stripped from conversation history breaks LLM KV cache

## What happens

`tool-parser.js` strips `<think>...</think>` blocks from assistant responses:

```js
// tool-calling/tool-parser.js
function stripThinkTags(content) {
    return content
        .replace(/<think>[\s\S]*?<\/think>/gi, '')
        .replace(/<think>[\s\S]*$/gi, '')
        .replace(/<\/think>/gi, '');
}
```

`conversation-loop.js` then stores the stripped version as the assistant message:

```js
// hooks/chat-handler/conversation/conversation-loop.js ~line 176
const assistantMsg = {
    role: 'assistant',
    content: cleanedContent,   // thinking already removed
    tool_calls: validToolCalls.length > 0 ? validToolCalls : undefined,
};
```

This stripped message is what gets saved to the session AND what gets sent back
to the LLM on every subsequent turn:

```js
// same file, line 90
const result = await client.chat([systemMessage, ...messages], tools, ...);
```

## Why it matters

The LLM server caches the full KV state of each response, including the thinking
tokens. On the next call, it compares the incoming message history against the
cache. Since the stored messages are missing the thinking tokens, the token
sequences diverge at the start of every assistant message. The cache is never
reused. Every turn reprocesses the full context from scratch (~15-20 seconds for
a long context).

This affects all sessions, including interactive ones. Any model that outputs
`<think>` blocks will see this: every message after the first one forces a full
context reprocess.

## Concrete example

Session 1, turn 1 sends to llama:
```
[system] + [user: "list files"]
```
Llama generates (and caches):
```
<think>I should call list_directory...</think>
```
followed by the tool call.

Session 1, turn 2 sends:
```
[system] + [user: "list files"] + [assistant: ""] + [tool: result] 
```
(thinking stripped, so assistant content is empty or just the tool call)

Llama cached: `<think>I should...`  
Llama receives: tool call with no thinking prefix  
-> sequences diverge at token ~2322 -> full reprocess.

## Fix

Keep the raw response (including thinking) in the conversation history sent to
the LLM, even if the cleaned version is shown in the UI. One approach:

```js
const assistantMsg = {
    role: 'assistant',
    content: fullContent,      // full content with thinking for LLM history
    tool_calls: validToolCalls.length > 0 ? validToolCalls : undefined,
};
// show cleanedContent in UI separately
addToChatQueue(<AssistantMessage message={cleanedContent} />);
```

Or store both and use `fullContent` when building the messages array for API
calls while using `cleanedContent` for display.

---

## Related: headless runs don't save at all

There is a second session storage bug specific to headless/non-interactive mode.

`useSessionAutosave` debounces saves with a 30-second interval (`saveInterval`).
The first save fires immediately (on the user message). When the assistant
response arrives, `timeSinceLastSave` is small, so a 30-second delayed save is
scheduled via `setTimeout`. In non-interactive mode, `useNonInteractiveMode`
calls `gracefulShutdown()` when the run completes. `ShutdownManager` runs its
registered handlers, but `useSessionAutosave` never registers one. The pending
`setTimeout` is cleared by `process.exit`. The session is saved with only the
user message.

Fix: register a shutdown handler in `useSessionAutosave` that cancels the
pending timeout and immediately flushes the save:

```js
// in useSessionAutosave, after the autosave init effect:
useEffect(() => {
    getShutdownManager().register({
        name: 'session-autosave',
        priority: 10,
        handler: async () => {
            if (timeoutRef.current) clearTimeout(timeoutRef.current);
            await saveSession();
        },
    });
    return () => getShutdownManager().unregister('session-autosave');
}, []);
```
