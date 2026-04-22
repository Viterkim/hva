# Feature: add csharp-ls to LSP server discovery

`csharp-ls` is not in `server-discovery.js` and `.cs` is not in the extension
map, so C# files get no LSP support even when `csharp-ls` is installed.

## Addition to server discovery list

```js
{
    name: 'csharp-ls',
    command: 'csharp-ls',
    args: [],
    languages: ['cs'],
    checkCommand: 'csharp-ls --version',
    verificationMethod: 'version',
    installHint: 'dotnet tool install --global csharp-ls',
},
```

## Addition to extension map

```js
cs: 'csharp',
```
