import fs from "node:fs";
import path from "node:path";

const extDir = process.argv[2] ?? "/hva/pi/extensions";
const targets = [
  {
    path: path.join(extDir, "node_modules/pi-lens/tools/lsp-navigation.ts"),
    typed: true,
  },
  {
    path: path.join(extDir, "node_modules/pi-lens/tools/lsp-navigation.js"),
    typed: false,
  },
];
let patchedTargets = 0;

for (const target of targets) {
  if (!fs.existsSync(target.path)) continue;
  patchedTargets += 1;

  let source = fs.readFileSync(target.path, "utf8");
  const opSig = target.typed
    ? "function emptyReasonForOperation(operation: string): string {\n"
    : "function emptyReasonForOperation(operation) {\n";
  const normalizer = target.typed
    ? `function normalizeHvaLspOperation(operation: string): string {
\tconst trimmed = operation.trim();
\tif (
\t\t(trimmed.startsWith('"') && trimmed.endsWith('"')) ||
\t\t(trimmed.startsWith("'") && trimmed.endsWith("'"))
\t) {
\t\ttry {
\t\t\tconst parsed = JSON.parse(trimmed);
\t\t\tif (typeof parsed === "string") return parsed;
\t\t} catch {
\t\t\treturn trimmed.slice(1, -1);
\t\t}
\t}
\treturn trimmed;
}

`
    : `function normalizeHvaLspOperation(operation) {
    const trimmed = operation.trim();
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
        try {
            const parsed = JSON.parse(trimmed);
            if (typeof parsed === "string")
                return parsed;
        }
        catch {
            return trimmed.slice(1, -1);
        }
    }
    return trimmed;
}

`;

  if (!source.includes("function normalizeHvaLspOperation")) {
    source = source.replace(opSig, `${normalizer}${opSig}`);
  }

  source = source.replaceAll(
    "HVA normalizes accidental quoted enum strings",
    "Accidental quoted enum strings",
  );

  if (target.typed) {
    source = source.replace(
      /\t\t\toperation: Type\.Union\(\n\t\t\t\t\[[\s\S]*?\n\t\t\t\t\{ description: "LSP operation to perform" \},\n\t\t\t\),/,
      `\t\t\toperation: Type.String({
\t\t\t\tdescription:
\t\t\t\t\t"LSP operation to perform. Accidental quoted enum strings such as \\\\\\"hover\\\\\\" are normalized.",
\t\t\t}),`,
    );
  } else {
    source = source.replace(
      /            operation: Type\.Union\(\[[\s\S]*?            \], \{ description: "LSP operation to perform" \}\),/,
      `            operation: Type.String({
                description: "LSP operation to perform. Accidental quoted enum strings such as \\"hover\\" are normalized.",
            }),`,
    );
  }

  if (target.typed) {
    source = source.replace(
      /\t\t\tconst \{\n\t\t\t\toperation,\n/,
      `\t\t\tconst {
\t\t\t\toperation: rawOperation,
`,
    );

    source = source.replace(
      /\t\t\t\} = params as \{\n\t\t\t\toperation: string;/,
      `\t\t\t} = params as {
\t\t\t\toperation: string;`,
    );

    source = source.replace(
      /\t\t\t\};\n\n\t\t\tconst operation = normalizeHvaLspOperation\(rawOperation\);\n\n\t\t\tconst operation = normalizeHvaLspOperation\(rawOperation\);\n\n\t\t\tconst isCallHierarchyTraversal =/,
      `\t\t\t};

\t\t\tconst operation = normalizeHvaLspOperation(rawOperation);

\t\t\tconst isCallHierarchyTraversal =`,
    );

    source = source.replace(
      /\t\t\t\};\n\n\t\t\tconst isCallHierarchyTraversal =/,
      `\t\t\t};

\t\t\tconst operation = normalizeHvaLspOperation(rawOperation);

\t\t\tconst isCallHierarchyTraversal =`,
    );
  } else {
    source = source.replace(
      /            const \{ operation, filePath: rawPath, line, character, endLine, endCharacter, newName, query, \} = params;\n            const isCallHierarchyTraversal =/,
      `            const { operation: rawOperation, filePath: rawPath, line, character, endLine, endCharacter, newName, query, } = params;
            const operation = normalizeHvaLspOperation(rawOperation);
            const isCallHierarchyTraversal =`,
    );
    source = source.replace(
      /            const operation = normalizeHvaLspOperation\(rawOperation\);\n            const operation = normalizeHvaLspOperation\(rawOperation\);\n/,
      `            const operation = normalizeHvaLspOperation(rawOperation);\n`,
    );
  }

  fs.writeFileSync(target.path, source);

  const patched = fs.readFileSync(target.path, "utf8");
  if (
    !patched.includes("function normalizeHvaLspOperation") ||
    !patched.includes("operation: Type.String") ||
    patched.includes("operation: Type.Union")
  ) {
    throw new Error(`failed to patch pi-lens lsp_navigation schema: ${target.path}`);
  }
}

if (patchedTargets === 0) {
  throw new Error("failed to find pi-lens lsp_navigation files to patch");
}
