# Bug: system prompt built before MCP servers finish connecting

`useAppInitialization.js` calls `setMcpInitialized(true)` before MCPs have
connected, and fires `initializeMCPServers` with `void` (fire-and-forget):

```js
setMcpInitialized(true); // too early
setStartChat(true);
void initializeMCPServers(newToolManager); // not awaited
```

`cachedBasePrompt` runs when `mcpInitialized` flips. At that point the tool
manager may have zero or partial tools registered. The system prompt content
is nondeterministic - it depends on a race between startup speed and MCP
connection time.

## Fix

```diff
- void initializeMCPServers(newToolManager);
- setMcpInitialized(true);
+ await initializeMCPServers(newToolManager);
  setStartChat(true);
```

Remove the earlier premature `setMcpInitialized(true)` call too. It should
only fire after all configured servers have connected and registered their tools.
