import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";
import { enabledMcp, envFlag } from "./common.ts";

const baseDir = dirname(fileURLToPath(import.meta.url));
const optionalSkillsBaseDir = join(
  baseDir,
  "..",
  "..",
  "skills",
  "auto",
  "mcp",
);
const runtimeBaseDir = join(baseDir, "..", "..", "hva-runtime");

const HVA_COMMAND_CHOICES = [
  {
    name: "hva-guidance-status",
    description: "show injected HVA runtime guidance",
  },
  {
    name: "hva-debug",
    description: "show HVA debug state and prompt inject details",
  },
  { name: "list-skills", description: "show HVA skills by group" },
  { name: "list-cmds", description: "show HVA commands and blessed flows" },
  {
    name: "use-skill",
    description: "pick a manual skill and insert the /skill call",
  },
  {
    name: "pwd-sys",
    description: "show the host path outside the container and save it",
  },
  { name: "hva-mcp-status", description: "show enabled HVA MCP-like tools" },
] as const;

const OPTIONAL_MCP_SKILLS = {
  ripgrep:
    "ripgrep - first stop for workspace text, errors, logs, config keys, refs, and where something is mentioned",
  searxng:
    "searxng - outside facts, release notes, docs sites, and web lookup after local and specific tools",
  "rust-docs":
    "rust-docs - first stop for any Rust crate question: API, usage, how it works, versions, docs.rs, features, deps. Never guess crate API or versions",
  github:
    "github - first stop for upstream GitHub repo code, files, PRs, issues, branches, and commits",
  pypi: "pypi - first stop for Python package versions, metadata, and exact package checks. Never guess versions",
  "npm-search":
    "npm-search - first stop for npm package search, versions, metadata, and release lookup. Never guess versions",
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
  return (
    process.env.HVA_PI_ACTIVE_SKILLS_DIR?.trim() || "/hva-state/skills-active"
  );
}

function gitMountEnabled(): boolean {
  return envFlag("HVA_MOUNT_GIT");
}

function gitMountReadonly(): boolean {
  return envFlag("HVA_MOUNT_GIT_READONLY");
}

function buildGitLine(): string {
  if (!gitMountEnabled()) {
    return "GIT: git folder is not mounted. do not use git commands.";
  }
  if (gitMountReadonly()) {
    return "GIT: git folder is mounted readonly. you can read (git log, diff, status, show) but never write, commit, stage, or push.";
  }
  return "GIT: git folder is mounted. never push.";
}

function buildRuntimeSection(): string {
  return [
    readRuntimeFile("global.md"),
    buildGitLine(),
  ].join("\n\n");
}

function stripFrontmatterValue(value: string): string {
  return value.trim().replace(/^["']/, "").replace(/["']$/, "");
}

function csvNames(value: string | undefined): string[] {
  return (value ?? "")
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

interface SkillEntry {
  name: string;
  description: string;
  path: string;
  dir: string;
  body: string;
}

type RuntimePromptMode = "normal" | "none" | "nudge" | "force";

function activeSkillEntries(
  kind: "auto" | "manual",
): Array<SkillEntry> {
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
        path: skillFile,
        dir: join(dir, entry),
        body: text.replace(/^---\n[\s\S]*?\n---\n?/, "").trim(),
      };
    })
    .filter((entry): entry is SkillEntry => entry !== undefined)
    .sort((a, b) => a.name.localeCompare(b.name));
}

function runtimePromptMode(): RuntimePromptMode {
  const value = (process.env.HVA_RUNTIME_PROMPT_MODE ?? "normal").trim();
  switch (value) {
    case "none":
    case "nudge":
    case "force":
      return value;
    default:
      return "normal";
  }
}

function buildSkillsList(): string {
  const autoSkills = activeSkillEntries("auto");
  const manualSkills = activeSkillEntries("manual");
  const enabledOptional = enabledOptionalSkillNames();
  const lines = [
    "always loaded",
    "- hva-runtime - injected runtime guidance",
    "- hva-guidance-status command",
    "- hva-debug command",
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
    ...manualSkills.map(
      (skill) => `- /skill:${skill.name} - ${skill.description}`,
    ),
  ];
  return lines.join("\n");
}

function buildSkillActivationGuidance(): string {
  const autoSkills = activeSkillEntries("auto");
  if (autoSkills.length === 0) {
    return "";
  }
  const promptMode = runtimePromptMode();
  if (promptMode === "none") {
    return "";
  }
  const skipAllInjects = envFlag("HVA_SKIP_ALL_INJECTS");
  const softInjectedSkills = csvNames(process.env.HVA_SOFT_INJECT_SKILLS);
  const hardInjectedSkills = csvNames(process.env.HVA_HARD_INJECT_SKILLS);
  if (promptMode === "nudge") {
    return [
      "SKILL ACTIVATION:",
      "- if a task matches a skill, load it before planning or editing files",
      "- use `activate_skill` or Pi `read` to load the full SKILL.md first",
      "- a skill description alone is only a catalog hint",
    ].join("\n");
  }
  if (promptMode === "force") {
    return [
      "SKILL ACTIVATION (mandatory):",
      "- if a task matches a skill, you must load it before planning or editing files",
      "- a matching skill overrides your default language, framework, and project-layout knowledge",
      "- do not continue until the matching skill is loaded",
      "- use `activate_skill` or Pi `read` to load the full SKILL.md first",
      "- a skill description alone is only a catalog hint",
    ].join("\n");
  }
  return [
    "SKILL ACTIVATION (mandatory):",
    ...(skipAllInjects
      ? ["- HVA skill injection is disabled by HVA_SKIP_ALL_INJECTS=1"]
      : []),
    ...(!skipAllInjects && hardInjectedSkills.length > 0
      ? ["- HVA hard injected skills below are already activated. follow them directly"]
      : []),
    ...(!skipAllInjects && softInjectedSkills.length > 0
      ? ["- HVA soft injected skills below are only match hints. load them with activate_skill first"]
      : []),
    "- available skill descriptions are still catalog only for everything else",
    "- when a task matches another skill, call `activate_skill` with that skill name before proceeding",
    "- do not assume you know a skill's body from its description alone",
  ].join("\n");
}

function buildCommandsList(): string {
  const manualSkills = activeSkillEntries("manual");
  const autoSkills = activeSkillEntries("auto");
  const hasGitReview = autoSkills.some((skill) => skill.name === "git-review");
  const lines = [
    "custom commands",
    ...HVA_COMMAND_CHOICES.map(
      (command) => `- /${command.name} - ${command.description}`,
    ),
    "- /git - prepare a local git review diff and send it to the agent",
    "",
    "blessed flows",
    ...manualSkills.map(
      (skill) => `- /skill:${skill.name} - ${skill.description}`,
    ),
    ...(hasGitReview
      ? [
        "- /skill:git-review main|branch <target>|commit <rev>|staged|unstaged|all - explicit local diff review",
      ]
      : []),
  ];
  return lines.join("\n");
}

function promptMatchesSkill(prompt: string, skillName: string): boolean {
  const text = prompt.toLowerCase();

  switch (skillName) {
    case "rust-style":
      return /\brust\b|\bcargo\b|cargo\.toml|\bcrate\b|\bclippy\b|\brustfmt\b|\.rs\b/.test(
        text,
      );
    case "js-ts-style":
      return /\bjavascript\b|\btypescript\b|\bnode\b|\bnpm\b|\bpnpm\b|\byarn\b|package\.json|tsconfig\.json|\.jsx?\b|\.tsx?\b/.test(
        text,
      );
    case "python-style":
      return /\bpython\b|\bpip\b|\bpytest\b|\bmypy\b|\bruff\b|pyproject\.toml|requirements\.txt|\.py\b/.test(
        text,
      );
    case "bash-style":
      return /\bbash\b|\bshell\b|\bshell script\b|\.sh\b|\bshfmt\b|\bshellcheck\b|\bzsh\b|\bfish\b/.test(
        text,
      );
    case "documentation":
      return /\bdocs?\b|\breadme\b|\bmarkdown\b|\.md\b/.test(text);
    case "review":
      return /\breview\b|\baudit\b|\blook for issues\b|\bcheck\b.*\b(issue|issues|bug|bugs|problem|problems|diff|changes|code)\b/.test(
        text,
      );
    case "git-review":
      return gitMountEnabled() &&
        /\b(git|diff|commit|branch|staged|unstaged|merge-base|changes)\b/.test(
          text,
        ) &&
        /\breview\b|\bdiff\b|\bcheck\b/.test(text);
    case "code":
      return /\bcreate\b|\bwrite\b|\badd\b|\bimplement\b|\bedit\b|\bfix\b|\bmake\b|\brefactor\b/.test(text);
    default:
      return false;
  }
}

function renderSkillContent(
  skill: SkillEntry,
  includeResources: boolean,
): string {
  const resources = includeResources ? listSkillResources(skill.dir) : [];
  return [
    `<skill_content name="${skill.name}">`,
    skill.body,
    "",
    `Skill directory: ${skill.dir}`,
    "Relative paths in this skill are relative to the skill directory.",
    ...(resources.length > 0
      ? [
          "",
          "<skill_resources>",
          ...resources.map((file) => `  <file>${file}</file>`),
          "</skill_resources>",
        ]
      : []),
    "</skill_content>",
  ].join("\n");
}

function injectedSkillEntries(mode: "soft" | "hard"): SkillEntry[] {
  if (envFlag("HVA_SKIP_ALL_INJECTS")) {
    return [];
  }
  const envValue = mode === "soft"
    ? process.env.HVA_SOFT_INJECT_SKILLS
    : process.env.HVA_HARD_INJECT_SKILLS;
  const names = new Set(csvNames(envValue));
  return activeSkillEntries("auto").filter((skill) => names.has(skill.name));
}

function buildSoftActivatedSkillSection(prompt: string): string {
  const matchedSkills = injectedSkillEntries("soft").filter((skill) =>
    promptMatchesSkill(prompt, skill.name)
  );
  if (matchedSkills.length === 0) {
    return "";
  }
  return [
    "SOFT MATCHED SKILLS:",
    ...matchedSkills.map(
      (skill) => `- ${skill.name} - ${skill.description}`,
    ),
    "- load them with `activate_skill` before proceeding",
  ].join("\n");
}

function buildHardActivatedSkillSection(prompt: string): string {
  const matchedSkills = injectedSkillEntries("hard").filter((skill) =>
    promptMatchesSkill(prompt, skill.name)
  );
  if (matchedSkills.length === 0) {
    return "";
  }
  return [
    "HARD INJECTED SKILLS (already activated):",
    ...matchedSkills.map((skill) => renderSkillContent(skill, false)),
  ].join("\n\n");
}

function buildInjection(prompt: string): string {
  const promptMode = runtimePromptMode();
  if (promptMode === "none") {
    return "";
  }
  const skillActivationGuidance = buildSkillActivationGuidance();
  const softActivatedSkills = buildSoftActivatedSkillSection(prompt);
  const hardActivatedSkills = buildHardActivatedSkillSection(prompt);
  const parts: string[] = [];
  if (promptMode === "normal") {
    parts.push("HVA RUNTIME (mandatory):", buildRuntimeSection());
  }
  if (skillActivationGuidance) {
    if (parts.length > 0) {
      parts.push("");
    }
    parts.push(skillActivationGuidance);
  }
  if (softActivatedSkills) {
    if (parts.length > 0) {
      parts.push("");
    }
    parts.push(softActivatedSkills);
  }
  if (hardActivatedSkills) {
    if (parts.length > 0) {
      parts.push("");
    }
    parts.push(hardActivatedSkills);
  }
  if (parts.length === 0) {
    return "";
  }
  return `\n${parts.join("\n")}\n`;
}

function buildHvaDebug(prompt: string, cwd: string): string {
  const trimmedPrompt = prompt.trim();
  const skipAllInjects = envFlag("HVA_SKIP_ALL_INJECTS");
  const autoSkills = activeSkillEntries("auto");
  const manualSkills = activeSkillEntries("manual");
  const softConfigured = new Set(csvNames(process.env.HVA_SOFT_INJECT_SKILLS));
  const hardConfigured = new Set(csvNames(process.env.HVA_HARD_INJECT_SKILLS));
  const dontInjectConfigured = new Set(csvNames(process.env.HVA_DONT_INJECT_SKILLS));
  const softMatched = autoSkills.filter((skill) =>
    softConfigured.has(skill.name) && promptMatchesSkill(trimmedPrompt, skill.name)
  );
  const hardMatched = autoSkills.filter((skill) =>
    hardConfigured.has(skill.name) && promptMatchesSkill(trimmedPrompt, skill.name)
  );

  const skillLines = autoSkills.map((skill) => {
    const configured = softConfigured.has(skill.name)
      ? "soft"
      : hardConfigured.has(skill.name)
      ? "hard"
      : dontInjectConfigured.has(skill.name)
      ? "dont-inject"
      : "unlisted";
    const matched = trimmedPrompt.length > 0
      ? (promptMatchesSkill(trimmedPrompt, skill.name) ? "yes" : "no")
      : "n/a";
    return `- ${skill.name} | configured=${configured} | prompt-match=${matched}`;
  });

  return [
    "HVA DEBUG",
    "",
    `cwd: ${cwd}`,
    `active skills dir: ${activeSkillsBaseDir()}`,
    `runtime prompt mode: ${runtimePromptMode()}`,
    `git mounted: ${gitMountEnabled() ? (gitMountReadonly() ? "yes (readonly)" : "yes") : "no"}`,
    `skip all injects: ${skipAllInjects ? "yes" : "no"}`,
    `soft inject config: ${csvNames(process.env.HVA_SOFT_INJECT_SKILLS).join(", ") || "(none)"}`,
    `hard inject config: ${csvNames(process.env.HVA_HARD_INJECT_SKILLS).join(", ") || "(none)"}`,
    `dont inject config: ${csvNames(process.env.HVA_DONT_INJECT_SKILLS).join(", ") || "(none)"}`,
    `enabled MCP tools: ${enabledOptionalSkillNames().join(", ") || "(none)"}`,
    "",
    `active auto skills: ${autoSkills.map((skill) => skill.name).join(", ") || "(none)"}`,
    `active manual skills: ${manualSkills.map((skill) => skill.name).join(", ") || "(none)"}`,
    "",
    trimmedPrompt.length > 0 ? `prompt: ${trimmedPrompt}` : "prompt: (none)",
    ...(
      trimmedPrompt.length > 0
        ? [
          `matched soft skills: ${softMatched.map((skill) => skill.name).join(", ") || "(none)"}`,
          `matched hard skills: ${hardMatched.map((skill) => skill.name).join(", ") || "(none)"}`,
        ]
        : [
          "matched soft skills: n/a",
          "matched hard skills: n/a",
        ]
    ),
    "",
    "auto skill match table:",
    ...skillLines,
    "",
    "final generated injection:",
    buildInjection(trimmedPrompt).trim(),
  ].join("\n");
}

function listSkillResources(skillDir: string, limit = 40): string[] {
  const results: string[] = [];
  const pending = [skillDir];

  while (pending.length > 0 && results.length < limit) {
    const current = pending.shift();
    if (!current) {
      continue;
    }
    for (const entry of readdirSync(current)) {
      const fullPath = join(current, entry);
      const relPath = fullPath.slice(`${skillDir}/`.length);
      if (relPath === "SKILL.md") {
        continue;
      }
      const stats = statSync(fullPath);
      if (stats.isDirectory()) {
        pending.push(fullPath);
        continue;
      }
      results.push(relPath);
      if (results.length >= limit) {
        break;
      }
    }
  }

  return results.sort();
}

function buildActivateSkillToolDescription(autoSkills: SkillEntry[]): string {
  return [
    "Load the full instructions for an available auto skill before you act.",
    "Use when a task matches one of these skills:",
    ...autoSkills.map((skill) => `- ${skill.name} - ${skill.description}`),
  ].join("\n");
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
  return join(
    sessionManager.getSessionDir(),
    `${sessionManager.getSessionId()}.pwd-sys.txt`,
  );
}

export default function (pi: ExtensionAPI) {
  const autoSkills = activeSkillEntries("auto");

  pi.on("resources_discover", () => {
    return {
      skillPaths: enabledOptionalSkillNames().map((name) =>
        join(optionalSkillsBaseDir, name, "SKILL.md"),
      ),
    };
  });

  pi.on("before_agent_start", async (event) => {
    const finalPrompt = `${event.systemPrompt}${buildInjection(event.prompt)}`;
    if (process.env.HVA_DUMP_SYSTEM_PROMPT) {
      writeFileSync(process.env.HVA_DUMP_SYSTEM_PROMPT, finalPrompt, "utf-8");
    }
    return {
      systemPrompt: finalPrompt,
    };
  });

  if (autoSkills.length > 0) {
    const skillNameSchema = autoSkills.length === 1
      ? Type.Literal(autoSkills[0].name, { description: "Skill name" })
      : Type.Union(
          autoSkills.map((skill) => Type.Literal(skill.name)),
          { description: "Skill name" },
        );

    pi.registerTool({
      name: "activate_skill",
      label: "Activate Skill",
      description: buildActivateSkillToolDescription(autoSkills),
      promptSnippet:
        "When a task matches an available skill, call activate_skill before proceeding.",
      promptGuidelines: [
        "Skill descriptions are only a catalog. Load the matching skill before using it.",
        "After activate_skill returns, follow the skill instructions instead of guessing.",
        "Treat paths mentioned inside the skill as relative to the reported skill directory.",
      ],
      parameters: Type.Object({
        name: skillNameSchema,
      }),
      async execute(_toolCallId, params) {
        const skill = autoSkills.find((entry) => entry.name === params.name);
        if (!skill) {
          throw new Error(`unknown skill: ${params.name}`);
        }
        const text = renderSkillContent(skill, true);

        return {
          content: [{ type: "text", text }],
          details: {
            name: skill.name,
            path: skill.path,
            dir: skill.dir,
          },
        };
      },
    });
  }

  pi.registerCommand("hva-guidance-status", {
    description: "Show HVA tool guidance",
    handler: async (_args, ctx) => {
      ctx.ui.notify(buildInjection(""), "info");
    },
  });

  pi.registerCommand("hva-debug", {
    description: "Show HVA debug state and prompt inject details",
    handler: async (args, ctx) => {
      ctx.ui.notify(buildHvaDebug(args, ctx.cwd), "info");
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
    description:
      "Pick a manual skill and insert the /skill call into the editor",
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

      const choice = GIT_COMMAND_CHOICES.find(
        (entry) => entry.label === picked,
      );
      if (!choice) {
        return;
      }

      let target = "";
      if ("mode" in choice) {
        if (choice.mode === "branch" || choice.mode === "commit") {
          const prompt =
            choice.mode === "branch"
              ? "Branch name or revision"
              : "Commit or revision";
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
        ctx.ui.notify(
          errorText || `git review helper failed with exit code ${result.code}`,
          "warning",
        );
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
    description:
      "Show the host path outside the container and save it in session state",
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
      ctx.ui.notify(
        `local-path-outside: ${outsidePath}\nsaved: ${outputPath}`,
        "info",
      );
    },
  });
}
