# Feature: env var to skip directory trust check in headless/CI environments

There is no way to pre-approve directories without the interactive UI. In
headless or CI environments the UI is never shown, so file access is blocked
with no way to unblock it.

## Requested

```bash
NANOCODER_TRUST_ALL_DIRECTORIES=1 nanocoder --headless --msg "..."
```

Same pattern as `git config --global safe.directory '*'`.

## Implementation

In `useDirectoryTrust.js`:

```diff
+ const trustAll = process.env.NANOCODER_TRUST_ALL_DIRECTORIES === '1';
  const trusted =
+   trustAll ||
    trustedDirectories.some(d => path.resolve(d) === normalizedDirectory);
```
