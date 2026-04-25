import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { enabledMcp } from "./common.ts";

const KNOWN_MCP = ["ripgrep", "searxng", "brave-search", "github", "npm-search", "pypi", "rust-docs"] as const;

function enabledMcpNames(): string[] {
  return KNOWN_MCP.filter((name) => enabledMcp(name));
}

function buildInjection(): string {
  const mcp = enabledMcpNames();

  const toolLines: string[] = [];
  if (enabledMcp("ripgrep")) {
    toolLines.push("- ripgrep_search: fast multi-file text search. Use before bash grep.");
  }
  if (enabledMcp("searxng") || enabledMcp("brave-search")) {
    toolLines.push("- web_search: external facts. web_fetch: full page content.");
  }
  if (enabledMcp("github")) {
    toolLines.push("- github_search_code, github_read_file: upstream code lookup.");
  }
  if (enabledMcp("npm-search")) {
    toolLines.push("- npm_package_search, npm_package_info: npm registry.");
  }
  if (enabledMcp("pypi")) {
    toolLines.push("- pypi_package_info: PyPI registry.");
  }
  if (enabledMcp("rust-docs")) {
    toolLines.push("- crates_search, crates_package_info, crates_dependencies, docs_rs_read: Rust/crates.io.");
  }
  toolLines.push("- lsp_navigation: definitions, references, hover, diagnostics, rename. Use before reading files.");

  const toolSection = toolLines.length > 0 ? `\nTools (use them, don't describe them):\n${toolLines.join("\n")}` : "";

  return `
RESPONSE STYLE (mandatory):
Caveman compression. One thought per sentence. 2-5 words per sentence max. No filler phrases. No tables. No "Would you like...". No "Here is...". No "Let me...". No "I'll...". Act, report result. Done.

HVA context:
- Enabled MCP groups: ${mcp.length > 0 ? mcp.join(", ") : "none"}.
- One miss proves nothing. Try another query.
- For lsp_navigation, operation must be a bare enum string like hover or workspaceDiagnostics. Never include extra quotes inside the string.
- Prefer tool call over claiming tool is unavailable.${toolSection}
`;
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event) => {
    return {
      systemPrompt: `${event.systemPrompt}${buildInjection()}`,
    };
  });

  pi.registerCommand("hva-guidance-status", {
    description: "Show HVA tool guidance",
    handler: async (_args, ctx) => {
      ctx.ui.notify(buildInjection(), "info");
    },
  });
}
