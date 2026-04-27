import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { enabledMcp, envFlag } from "./common.ts";

const baseDir = dirname(fileURLToPath(import.meta.url));
const optionalSkillsBaseDir = join(baseDir, "..", "..", "skills", "auto", "mcp");
const runtimeBaseDir = join(baseDir, "..", "..", "hva-runtime");

const KNOWN_MCP = [
  "ripgrep",
  "searxng",
  "brave-search",
  "github",
  "npm-search",
  "pypi",
  "rust-docs",
] as const;

const MANUAL_SKILL_CHOICES = [
  { name: "hva-new-skill", description: "make or change HVA skills and extensions" },
  { name: "hva-review", description: "HVA repo review checklist" },
  { name: "planner", description: "plan.md and knowns.md workflow" },
  { name: "read-repo", description: "preview, ignore, and load a repo or subpath into context" },
] as const;

const MANUAL_SKILLS = MANUAL_SKILL_CHOICES.map(
  (skill) => `/skill:${skill.name} - ${skill.description}`,
);

const HVA_COMMAND_CHOICES = [
  { name: "hva-guidance-status", description: "show injected HVA runtime guidance" },
  { name: "list-skills", description: "show HVA skills by group" },
  { name: "list-cmds", description: "show HVA commands and blessed flows" },
  { name: "use-skill", description: "pick a manual skill and insert the /skill call" },
  { name: "pwd-sys", description: "show the host path outside the container and save it" },
  { name: "hva-mcp-status", description: "show enabled HVA MCP-like tools" },
] as const;

const AUTO_SKILLS = [
  "bash-style - bash and shell writing",
  "documentation - markdown and docs writing",
  "review - soft code review",
  "ast-grep - structural code search and rewrite",
  "lsp-navigation - definitions, refs, diagnostics, symbols",
] as const;

const OPTIONAL_MCP_SKILLS = {
  ripgrep: "ripgrep - workspace text search with ripgrep_search",
  searxng: "searxng - web_search and web_fetch for outside facts",
  "rust-docs": "rust-docs - crates_search, crates_package_info, docs_rs_read",
  github: "github - repo code search and file lookup",
  pypi: "pypi - Python package lookup",
  "npm-search": "npm-search - npm package lookup",
} as const;

const GIT_COMMAND_CHOICES = [
  { label: "review vs main", mode: "main" },
  { label: "review staged", mode: "staged" },
  { label: "review unstaged", mode: "unstaged" },
  { label: "review all local changes", mode: "all" },
  { label: "review vs branch...", mode: "branch" },
  { label: "review vs commit...", mode: "commit" },
] as const;

function enabledMcpNames(): string[] {
  return KNOWN_MCP.filter((name) => enabledMcp(name));
}

function enabledOptionalSkillNames(): Array<keyof typeof OPTIONAL_MCP_SKILLS> {
  return Object.keys(OPTIONAL_MCP_SKILLS).filter((name) =>
    enabledMcp(name),
  ) as Array<keyof typeof OPTIONAL_MCP_SKILLS>;
}

function readRuntimeFile(name: string): string {
  return readFileSync(join(runtimeBaseDir, name), "utf-8").trim();
}

function gitMountEnabled(): boolean {
  return envFlag("HVA_MOUNT_GIT");
}

function buildRuntimeSection(): string {
  const parts = [
    readRuntimeFile("runtime.md"),
    readRuntimeFile(gitMountEnabled() ? "git-yes.md" : "git-no.md"),
    readRuntimeFile("analysis.md"),
    readRuntimeFile("style.md"),
    readRuntimeFile("searching.md"),
  ];
  return parts.join("\n\n");
}

function buildSkillsList(): string {
  const enabledOptional = enabledOptionalSkillNames();
  const lines = [
    "always loaded",
    "- hva-runtime - injected runtime guidance",
    gitMountEnabled()
      ? "- git-yes - git mounted"
      : "- git-no - no git access",
    "- list-skills command",
    "- list-cmds command",
    "- use-skill command",
    ...(gitMountEnabled() ? ["- git command"] : []),
    "",
    "loaded by context",
    ...AUTO_SKILLS.map((skill) => `- ${skill}`),
    ...(gitMountEnabled()
      ? ["- hva-git-review - local git diff review inside HVA"]
      : []),
    ...enabledOptional.map((name) => `- ${OPTIONAL_MCP_SKILLS[name]}`),
    "",
    "manual",
    ...MANUAL_SKILLS.map((skill) => `- ${skill}`),
  ];
  return lines.join("\n");
}

function buildCommandsList(): string {
  const lines = [
    "custom commands",
    ...HVA_COMMAND_CHOICES.map((command) => `- /${command.name} - ${command.description}`),
    ...(gitMountEnabled() ? ["- /git - prepare a local git review diff and send it to the agent"] : []),
    "",
    "blessed flows",
    ...MANUAL_SKILLS.map((skill) => `- ${skill}`),
    ...(gitMountEnabled()
      ? ["- /skill:hva-git-review main|branch <target>|commit <rev>|staged|unstaged|all - local git diff review"]
      : []),
  ];
  return lines.join("\n");
}

function buildInjection(): string {
  const searchOrder = buildSearchOrderSection();
  const mcp = enabledMcpNames();
  const enabledMcpLines = mcp.length > 0
    ? mcp.map((name) => `- ${name}`).join("\n")
    : "- none";

  return `
${searchOrder ? `SEARCH ORDER (mandatory):\n${searchOrder}\n\n` : ""}\

HVA RUNTIME (mandatory):
${buildRuntimeSection()}

TOOL PRIORITY (mandatory):
${buildToolPrioritySection()}

ENABLED MCP (info):
${enabledMcpLines}
`;
}

function buildSearchOrderSection(): string {
  const lines = [];

  if (enabledMcp("ripgrep")) {
    lines.push("- Text inside workspace files: `ripgrep_search` first.");
    lines.push("- File names, file counts, and listing: `ls` or `find` first.");
    lines.push("- Not bash grep. Not `find | grep`. Not `ls | grep`.");
  }

  return lines.join("\n");
}

function buildToolPrioritySection(): string {
  const lines = [];

  if (enabledMcp("ripgrep")) {
    lines.push("- Text inside workspace files: `ripgrep_search` first.");
    lines.push("- File-name search, file counts, and file listing: `ls` or `find` first.");
    lines.push("- Do not use bash grep or bash ls/find/grep pipelines when built-in tools can answer.");
  }
  if (enabledMcp("rust-docs")) {
    lines.push("- Rust crates, docs.rs, and crate versions: rust-docs tools first.");
    lines.push("- Latest crate version: `crates_package_info` first.");
    lines.push("- Do not use web_search for Rust crate questions unless rust-docs tools cannot answer.");
  }
  if (enabledMcp("github")) {
    lines.push("- GitHub repo code and file lookup: GitHub tools first.");
  }
  if (enabledMcp("pypi")) {
    lines.push("- Python package lookup: PyPI tools first.");
  }
  if (enabledMcp("npm-search")) {
    lines.push("- npm package lookup: npm tools first.");
  }
  if (enabledMcp("searxng")) {
    lines.push("- Outside facts: `web_search` and `web_fetch` after the more specific tools above.");
  }
  if (gitMountEnabled()) {
    lines.push("- Local git review: run `/hva/internals/git-diff.sh` first. Do not start with `git diff`, `git status`, or `git log` unless the helper fails.");
  }

  return lines.join("\n");
}

function diffReviewLabel(
  mode: "main" | "branch" | "commit" | "staged" | "unstaged" | "all",
  target: string,
): string {
  switch (mode) {
    case "unstaged":
      return "unstaged changes";
    case "staged":
      return "staged changes";
    case "commit":
      return `diff from ${target} to HEAD`;
    case "branch":
      return `diff from merge-base(${target}, HEAD) to HEAD`;
    case "main":
      return "diff from merge-base(main/master, HEAD) to HEAD";
    case "all":
      return "all changes";
  }
}

function diffReviewPrompt(label: string, diffContent: string): string {
  return [
    readRuntimeFile("diff-review.md"),
    "",
    `Review target: ${label}`,
    "",
    "Diff:",
    "```diff",
    diffContent,
    "```",
  ].join("\n");
}

function diffReviewSoftLimitBytes(): number | undefined {
  const contextSize = Number.parseInt(process.env.LLAMA_CONTEXT_SIZE ?? "", 10);
  if (!Number.isFinite(contextSize) || contextSize <= 0) {
    return undefined;
  }
  return contextSize * 3;
}

function localPathOutside(cwd: string): string {
  const hostWorkspacePath = process.env.HVA_HOST_WORKSPACE_PATH?.trim();
  if (!hostWorkspacePath) {
    return cwd;
  }
  if (cwd === "/workspace") {
    return hostWorkspacePath;
  }
  if (cwd.startsWith("/workspace/")) {
    return join(hostWorkspacePath, cwd.slice("/workspace/".length));
  }
  return cwd;
}

function pwdSysFilePath(sessionManager: {
  getSessionFile(): string | undefined;
  getSessionDir(): string;
  getSessionId(): string;
}): string {
  const sessionFile = sessionManager.getSessionFile();
  if (sessionFile) {
    return `${sessionFile}.pwd-sys.txt`;
  }
  return join(sessionManager.getSessionDir(), `${sessionManager.getSessionId()}.pwd-sys.txt`);
}

export default function (pi: ExtensionAPI) {
  pi.on("resources_discover", () => {
    return {
      skillPaths: enabledOptionalSkillNames().map((name) =>
        join(optionalSkillsBaseDir, name, "SKILL.md"),
      ),
    };
  });

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

  pi.registerCommand("list-skills", {
    description: "Show HVA skills by group",
    handler: async (_args, ctx) => {
      ctx.ui.notify(buildSkillsList(), "info");
    },
  });

  pi.registerCommand("list-cmds", {
    description: "Show HVA commands and blessed flows",
    handler: async (_args, ctx) => {
      ctx.ui.notify(buildCommandsList(), "info");
    },
  });

  pi.registerCommand("use-skill", {
    description: "Pick a manual skill and insert the /skill call into the editor",
    handler: async (_args, ctx) => {
      const options = MANUAL_SKILL_CHOICES.map(
        (skill) => `/skill:${skill.name} - ${skill.description}`,
      );
      const picked = await ctx.ui.select("Use skill", options);
      if (!picked) {
        return;
      }
      const skill = MANUAL_SKILL_CHOICES.find(
        (entry) => picked === `/skill:${entry.name} - ${entry.description}`,
      );
      if (!skill) {
        return;
      }
      ctx.ui.setEditorText(`/skill:${skill.name} `);
      ctx.ui.notify(`Inserted /skill:${skill.name} into the editor`, "info");
    },
  });

  pi.registerCommand("git", {
    description: "Prepare a local git review diff and send it to the agent",
    handler: async (_args, ctx) => {
      if (!gitMountEnabled()) {
        ctx.ui.notify("Git is not mounted in this session", "warning");
        return;
      }

      const picked = await ctx.ui.select(
        "Git",
        GIT_COMMAND_CHOICES.map((choice) => choice.label),
      );
      if (!picked) {
        return;
      }

      const choice = GIT_COMMAND_CHOICES.find((entry) => entry.label === picked);
      if (!choice) {
        return;
      }

      let target = "";
      if ("mode" in choice) {
        if (choice.mode === "branch" || choice.mode === "commit") {
          const prompt = choice.mode === "branch" ? "Branch name or revision" : "Commit or revision";
          const value = await ctx.ui.input("Git", prompt);
          if (!value) {
            return;
          }
          target = value.trim();
        }
      }

      const result = await pi.exec(
        "bash",
        ["/hva/internals/git-diff.sh", choice.mode, target, ctx.cwd],
        { cwd: ctx.cwd },
      );
      const diffContent = `${result.stdout ?? ""}`.trim();
      const errorText = `${result.stderr ?? ""}`.trim();
      const label = diffReviewLabel(choice.mode, target);

      if (result.code !== 0) {
        ctx.ui.notify(errorText || `git review helper failed with exit code ${result.code}`, "warning");
        return;
      }
      if (!diffContent) {
        ctx.ui.notify(`no ${label}`, "info");
        return;
      }

      const diffBytes = Buffer.byteLength(diffContent, "utf8");
      const softLimitBytes = diffReviewSoftLimitBytes();
      if (softLimitBytes && diffBytes > softLimitBytes) {
        ctx.ui.notify(
          `diff too large for review: ${label}\nbytes: ${diffBytes}\nsoft limit: ${softLimitBytes}\ntry a narrower target`,
          "warning",
        );
        return;
      }

      pi.sendUserMessage(diffReviewPrompt(label, diffContent));
    },
  });

  pi.registerCommand("pwd-sys", {
    description: "Show the host path outside the container and save it in session state",
    handler: async (_args, ctx) => {
      const outsidePath = localPathOutside(ctx.cwd);
      const outputPath = pwdSysFilePath(ctx.sessionManager);
      writeFileSync(
        outputPath,
        [
          `local-path-outside: ${outsidePath}`,
          `inside-path: ${ctx.cwd}`,
          `saved-at: ${new Date().toISOString()}`,
        ].join("\n") + "\n",
      );
      ctx.ui.notify(`local-path-outside: ${outsidePath}\nsaved: ${outputPath}`, "info");
    },
  });
}
