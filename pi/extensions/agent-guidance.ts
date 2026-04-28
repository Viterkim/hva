import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { enabledMcp, envFlag } from "./common.ts";

const baseDir = dirname(fileURLToPath(import.meta.url));
const optionalSkillsBaseDir = join(baseDir, "..", "..", "skills", "auto", "mcp");
const runtimeBaseDir = join(baseDir, "..", "..", "hva-runtime");

const HVA_COMMAND_CHOICES = [
  { name: "hva-guidance-status", description: "show injected HVA runtime guidance" },
  { name: "list-skills", description: "show HVA skills by group" },
  { name: "list-cmds", description: "show HVA commands and blessed flows" },
  { name: "use-skill", description: "pick a manual skill and insert the /skill call" },
  { name: "pwd-sys", description: "show the host path outside the container and save it" },
  { name: "hva-mcp-status", description: "show enabled HVA MCP-like tools" },
] as const;

const OPTIONAL_MCP_SKILLS = {
  ripgrep: "ripgrep - first stop for workspace text, errors, logs, config keys, refs, and where something is mentioned",
  searxng: "searxng - outside facts, release notes, docs sites, and web lookup after local and specific tools",
  "rust-docs": "rust-docs - first stop for Rust crates, versions, docs.rs, features, deps, and examples. Never guess versions",
  github: "github - first stop for upstream GitHub repo code, files, PRs, issues, branches, and commits",
  pypi: "pypi - first stop for Python package versions, metadata, and exact package checks. Never guess versions",
  "npm-search": "npm-search - first stop for npm package search, versions, metadata, and release lookup. Never guess versions",
} as const;

const GIT_COMMAND_CHOICES = [
  { label: "review vs main", mode: "main" },
  { label: "review staged", mode: "staged" },
  { label: "review unstaged", mode: "unstaged" },
  { label: "review all local changes", mode: "all" },
  { label: "review vs branch...", mode: "branch" },
  { label: "review vs commit...", mode: "commit" },
] as const;

function enabledOptionalSkillNames(): Array<keyof typeof OPTIONAL_MCP_SKILLS> {
  return Object.keys(OPTIONAL_MCP_SKILLS).filter((name) =>
    enabledMcp(name),
  ) as Array<keyof typeof OPTIONAL_MCP_SKILLS>;
}

function readRuntimeFile(name: string): string {
  return readFileSync(join(runtimeBaseDir, name), "utf-8").trim();
}

function activeSkillsBaseDir(): string {
  return process.env.HVA_PI_ACTIVE_SKILLS_DIR?.trim() || "/hva-state/skills-active";
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
  ];
  return parts.join("\n\n");
}

function stripFrontmatterValue(value: string): string {
  return value.trim().replace(/^["']/, "").replace(/["']$/, "");
}

function activeSkillEntries(kind: "auto" | "manual"): Array<{ name: string; description: string }> {
  const dir = join(activeSkillsBaseDir(), kind);
  if (!existsSync(dir)) {
    return [];
  }

  return readdirSync(dir)
    .map((entry) => {
      const skillFile = join(dir, entry, "SKILL.md");
      if (!existsSync(skillFile)) {
        return undefined;
      }
      const text = readFileSync(skillFile, "utf-8");
      const frontmatter = text.match(/^---\n([\s\S]*?)\n---/);
      if (!frontmatter) {
        return undefined;
      }
      const nameLine = frontmatter[1].match(/^name:\s*(.+)$/m);
      const descriptionLine = frontmatter[1].match(/^description:\s*(.+)$/m);
      if (!nameLine || !descriptionLine) {
        return undefined;
      }
      return {
        name: stripFrontmatterValue(nameLine[1]),
        description: stripFrontmatterValue(descriptionLine[1]),
      };
    })
    .filter((entry): entry is { name: string; description: string } => entry !== undefined)
    .sort((a, b) => a.name.localeCompare(b.name));
}

function buildSkillsList(): string {
  const autoSkills = activeSkillEntries("auto");
  const manualSkills = activeSkillEntries("manual");
  const enabledOptional = enabledOptionalSkillNames();
  const lines = [
    "always loaded",
    "- hva-runtime - injected runtime guidance",
    "- list-skills command",
    "- list-cmds command",
    "- use-skill command",
    "- git command",
    "",
    "loaded by context",
    ...autoSkills.map((skill) => `- ${skill.name} - ${skill.description}`),
    ...enabledOptional.map((name) => `- ${OPTIONAL_MCP_SKILLS[name]}`),
    "",
    "manual",
    ...manualSkills.map((skill) => `- /skill:${skill.name} - ${skill.description}`),
  ];
  return lines.join("\n");
}

function buildCommandsList(): string {
  const manualSkills = activeSkillEntries("manual");
  const autoSkills = activeSkillEntries("auto");
  const hasGitReview = autoSkills.some((skill) => skill.name === "git-review");
  const lines = [
    "custom commands",
    ...HVA_COMMAND_CHOICES.map((command) => `- /${command.name} - ${command.description}`),
    "- /git - prepare a local git review diff and send it to the agent",
    "",
    "blessed flows",
    ...manualSkills.map((skill) => `- /skill:${skill.name} - ${skill.description}`),
    ...autoSkills
      .filter((skill) => skill.name === "git-yes" || skill.name === "git-no")
      .map((skill) => `- /skill:${skill.name} - ${skill.description}`),
    ...(hasGitReview
      ? ["- /skill:git-review main|branch <target>|commit <rev>|staged|unstaged|all - explicit local diff review"]
      : []),
  ];
  return lines.join("\n");
}

function buildInjection(): string {
  return `
HVA RUNTIME (mandatory):
${buildRuntimeSection()}
`;
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
      const manualSkills = activeSkillEntries("manual");
      if (manualSkills.length === 0) {
        ctx.ui.notify("No manual skills are active in this session", "warning");
        return;
      }
      const options = manualSkills.map(
        (skill) => `/skill:${skill.name} - ${skill.description}`,
      );
      const picked = await ctx.ui.select("Use skill", options);
      if (!picked) {
        return;
      }
      const skill = manualSkills.find(
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
