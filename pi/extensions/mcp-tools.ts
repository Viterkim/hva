import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";
import { enabledMcp } from "./common.ts";

export async function fetchJson(url: string, init?: RequestInit) {
  const response = await fetch(url, init);
  if (!response.ok) {
    throw new Error(
      `request failed: ${response.status} ${response.statusText}`,
    );
  }
  return response.json();
}

export async function fetchText(url: string, init?: RequestInit) {
  const response = await fetch(url, init);
  if (!response.ok) {
    throw new Error(
      `request failed: ${response.status} ${response.statusText}`,
    );
  }
  return response.text();
}

export function stripHtml(html: string) {
  return html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&#39;/gi, "'")
    .replace(/&quot;/gi, '"')
    .replace(/\s+/g, " ")
    .trim();
}

export async function searxngSearch(query: string, limit: number) {
  const baseUrl = process.env.SEARXNG_URL ?? "http://127.0.0.1:8888";
  const url = new URL("/search", baseUrl);
  url.searchParams.set("q", query);
  url.searchParams.set("format", "json");
  const payload = (await fetchJson(url.toString(), {
    headers: {
      "X-Real-IP": "127.0.0.1",
    },
  })) as {
    results?: Array<{ title?: string; url?: string; content?: string }>;
  };
  return (payload.results ?? []).slice(0, limit);
}

export async function braveSearch(query: string, limit: number) {
  const token = process.env.BRAVE_API_KEY;
  if (!token) {
    throw new Error("BRAVE_API_KEY is not set");
  }
  const url = new URL("https://api.search.brave.com/res/v1/web/search");
  url.searchParams.set("q", query);
  url.searchParams.set("count", String(limit));
  const payload = (await fetchJson(url.toString(), {
    headers: {
      Accept: "application/json",
      "X-Subscription-Token": token,
    },
  })) as {
    web?: {
      results?: Array<{ title?: string; url?: string; description?: string }>;
    };
  };
  return (payload.web?.results ?? []).slice(0, limit);
}

export function githubHeaders() {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "User-Agent": "hva-pi-tools",
  };
  const token =
    process.env.GITHUB_PERSONAL_ACCESS_TOKEN ?? process.env.GITHUB_TOKEN;
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  return headers;
}

export async function githubSearchRepositories(query: string, limit: number) {
  const headers = githubHeaders();
  const url = new URL("https://api.github.com/search/repositories");
  url.searchParams.set("q", query);
  url.searchParams.set("per_page", String(limit));
  const payload = (await fetchJson(url.toString(), { headers })) as {
    items?: Array<{
      full_name?: string;
      html_url?: string;
      description?: string;
      stargazers_count?: number;
    }>;
  };
  return payload.items ?? [];
}

export async function githubSearchCode(query: string, limit: number) {
  const headers = githubHeaders();
  const url = new URL("https://api.github.com/search/code");
  url.searchParams.set("q", query);
  url.searchParams.set("per_page", String(limit));
  const payload = (await fetchJson(url.toString(), { headers })) as {
    items?: Array<{
      name?: string;
      path?: string;
      html_url?: string;
      repository?: { full_name?: string };
    }>;
  };
  return payload.items ?? [];
}

export async function githubReadFile(
  owner: string,
  repo: string,
  path: string,
  ref: string | undefined,
) {
  const headers = githubHeaders();
  const url = githubContentsUrl(owner, repo, path);
  if (ref) {
    url.searchParams.set("ref", ref);
  }
  const payload = (await fetchJson(url.toString(), { headers })) as {
    content?: string;
    encoding?: string;
    download_url?: string;
  };
  if (payload.encoding === "base64" && payload.content) {
    return Buffer.from(payload.content.replace(/\n/g, ""), "base64").toString(
      "utf8",
    );
  }
  if (payload.download_url) {
    const response = await fetch(payload.download_url);
    if (!response.ok) {
      throw new Error(`download failed: ${response.status}`);
    }
    return response.text();
  }
  throw new Error("github response had no readable content");
}

export async function githubListDirectory(
  owner: string,
  repo: string,
  path: string,
  ref: string | undefined,
) {
  const headers = githubHeaders();
  const url = githubContentsUrl(owner, repo, path);
  if (ref) {
    url.searchParams.set("ref", ref);
  }
  const payload = (await fetchJson(url.toString(), { headers })) as
    | Array<{
        name?: string;
        path?: string;
        type?: string;
        size?: number;
        html_url?: string;
      }>
    | {
        name?: string;
        path?: string;
        type?: string;
        size?: number;
        html_url?: string;
      };
  return Array.isArray(payload) ? payload : [payload];
}

export async function cratesPackageInfo(crateName: string) {
  return fetchJson(
    `https://crates.io/api/v1/crates/${encodeURIComponent(crateName)}`,
    {
      headers: {
        "User-Agent": "hva-pi-tools",
      },
    },
  );
}

export async function cratesDependencies(
  crateName: string,
  version: string | undefined,
) {
  let resolvedVersion = version;
  if (!resolvedVersion) {
    const info = (await cratesPackageInfo(crateName)) as {
      crate?: { newest_version?: string };
    };
    resolvedVersion = info.crate?.newest_version;
  }
  if (!resolvedVersion) {
    throw new Error(`could not resolve latest version for crate: ${crateName}`);
  }
  return fetchJson(
    `https://crates.io/api/v1/crates/${encodeURIComponent(crateName)}/${encodeURIComponent(resolvedVersion)}/dependencies`,
    {
      headers: {
        "User-Agent": "hva-pi-tools",
      },
    },
  );
}

export async function docsRsRead(
  crateName: string,
  version: string | undefined,
  path: string | undefined,
) {
  const url = new URL(
    `https://docs.rs/${encodeURIComponent(crateName)}/${version ? encodeURIComponent(version) : "latest"}/${path?.replace(/^\/+/, "") ?? ""}`,
  );
  const body = await fetchText(url.toString(), {
    headers: {
      "User-Agent": "hva-pi-tools",
    },
  });
  return {
    url: url.toString(),
    text: stripHtml(body),
  };
}

function githubContentsUrl(owner: string, repo: string, path: string) {
  const normalizedPath = path.replace(/^\/+/, "");
  const encodedPath =
    normalizedPath === ""
      ? ""
      : normalizedPath.split("/").map(encodeURIComponent).join("/");
  return new URL(
    `https://api.github.com/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/contents/${encodedPath}`,
  );
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("hva-mcp-status", {
    description: "Show enabled HVA Pi external tools",
    handler: async (_args, ctx) => {
      const enabled = [
        "ripgrep",
        "searxng",
        "brave-search",
        "github",
        "npm-search",
        "pypi",
        "rust-docs",
      ].filter((name) => enabledMcp(name));
      ctx.ui.notify(`MCP-like tools: ${enabled.join(", ") || "none"}`, "info");
    },
  });

  if (enabledMcp("ripgrep")) {
    pi.registerTool({
      name: "ripgrep_search",
      label: "Ripgrep Search",
      description: "Search workspace files with ripgrep.",
      promptSnippet: "Use ripgrep_search for fast broad workspace search.",
      promptGuidelines: [
        "Use ripgrep_search before slower shell search for multi-file text lookup.",
        "If one query misses, try another pattern or glob before assuming absence.",
      ],
      parameters: Type.Object({
        pattern: Type.String({ description: "Ripgrep pattern" }),
        glob: Type.Optional(
          Type.String({ description: "Optional glob filter like '*.ts'" }),
        ),
        maxResults: Type.Optional(
          Type.Number({
            description: "Optional per-file match cap. Omit for no rg cap.",
          }),
        ),
      }),
      async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
        const args = ["-n", "--color", "never"];
        if (params.maxResults && params.maxResults > 0) {
          args.push("--max-count", String(params.maxResults));
        }
        if (params.glob) {
          args.push("--glob", params.glob);
        }
        args.push(params.pattern, ".");
        const result = await pi.exec("rg", args, { cwd: ctx.cwd });
        const text =
          `${result.stdout ?? ""}${result.stderr ?? ""}`.trim() ||
          "No matches.";
        return {
          content: [{ type: "text", text }],
          details: { exitCode: result.code },
        };
      },
    });
  }

  if (enabledMcp("searxng") || enabledMcp("brave-search")) {
    pi.registerTool({
      name: "web_search",
      label: "Web Search",
      description: "Search the web with configured HVA search backends.",
      promptSnippet:
        "Use web_search for current web facts when local repo context is not enough.",
      promptGuidelines: [
        "Use web_search when facts may have changed or repository context is insufficient.",
        "Use web_fetch after web_search when snippets are not enough.",
      ],
      parameters: Type.Object({
        query: Type.String({ description: "Search query" }),
        limit: Type.Optional(
          Type.Number({ description: "Requested result count", default: 10 }),
        ),
      }),
      async execute(_toolCallId, params) {
        const limit = params.limit ?? 10;
        const results = enabledMcp("searxng")
          ? await searxngSearch(params.query, limit)
          : await braveSearch(params.query, limit);
        const text =
          results.length === 0
            ? "No results."
            : results
                .map((r, i) => {
                  const title = r.title ?? "";
                  const url = r.url ?? "";
                  const snippet =
                    (r as { content?: string; description?: string }).content ??
                    (r as { content?: string; description?: string })
                      .description ??
                    "";
                  return `[${i + 1}] ${title}\n${url}${snippet ? `\n${snippet}` : ""}`;
                })
                .join("\n\n");
        return {
          content: [{ type: "text", text }],
          details: results,
        };
      },
    });

    pi.registerTool({
      name: "web_fetch",
      label: "Web Fetch",
      description: "Fetch a URL and return simplified text content.",
      promptSnippet:
        "Use web_fetch after web_search when you need page contents, not only search snippets.",
      parameters: Type.Object({
        url: Type.String({ description: "HTTP or HTTPS URL" }),
      }),
      async execute(_toolCallId, params) {
        const text = await fetchText(params.url, {
          headers: {
            "User-Agent": "hva-pi-tools",
          },
        });
        const body = params.url.endsWith(".json") ? text : stripHtml(text);
        return {
          content: [
            { type: "text", text: body.slice(0, 20000) || "Empty response." },
          ],
          details: { bytes: text.length },
        };
      },
    });
  }

  if (enabledMcp("github")) {
    pi.registerTool({
      name: "github_search_repositories",
      label: "GitHub Repo Search",
      description: "Search GitHub repositories.",
      parameters: Type.Object({
        query: Type.String({ description: "GitHub repository search query" }),
        limit: Type.Optional(
          Type.Number({ description: "Maximum results", default: 5 }),
        ),
      }),
      async execute(_toolCallId, params) {
        const results = await githubSearchRepositories(
          params.query,
          params.limit ?? 5,
        );
        const text =
          results.length === 0
            ? "No results."
            : results
                .map((r, i) => {
                  const desc = r.description ? `\n${r.description}` : "";
                  return `[${i + 1}] ${r.full_name ?? ""}  ⭐${r.stargazers_count ?? 0}${desc}\n${r.html_url ?? ""}`;
                })
                .join("\n\n");
        return {
          content: [{ type: "text", text }],
          details: results,
        };
      },
    });

    pi.registerTool({
      name: "github_search_code",
      label: "GitHub Code Search",
      description: "Search public GitHub code results.",
      parameters: Type.Object({
        query: Type.String({ description: "GitHub code search query" }),
        limit: Type.Optional(
          Type.Number({ description: "Maximum results", default: 5 }),
        ),
      }),
      async execute(_toolCallId, params) {
        const results = await githubSearchCode(params.query, params.limit ?? 5);
        const text =
          results.length === 0
            ? "No results."
            : results
                .map(
                  (r, i) =>
                    `[${i + 1}] ${r.repository?.full_name ?? ""}/${r.path ?? ""}\n${r.html_url ?? ""}`,
                )
                .join("\n\n");
        return {
          content: [{ type: "text", text }],
          details: results,
        };
      },
    });

    pi.registerTool({
      name: "github_read_file",
      label: "GitHub Read File",
      description: "Read file contents from a GitHub repository.",
      parameters: Type.Object({
        owner: Type.String({ description: "Repository owner" }),
        repo: Type.String({ description: "Repository name" }),
        path: Type.String({ description: "File path inside repository" }),
        ref: Type.Optional(
          Type.String({ description: "Branch, tag, or commit" }),
        ),
      }),
      async execute(_toolCallId, params) {
        const content = await githubReadFile(
          params.owner,
          params.repo,
          params.path,
          params.ref,
        );
        return {
          content: [{ type: "text", text: content }],
          details: { bytes: content.length },
        };
      },
    });

    pi.registerTool({
      name: "github_list_directory",
      label: "GitHub List Directory",
      description: "List directory entries from a GitHub repository.",
      parameters: Type.Object({
        owner: Type.String({ description: "Repository owner" }),
        repo: Type.String({ description: "Repository name" }),
        path: Type.Optional(
          Type.String({
            description: "Directory path inside repository",
            default: "",
          }),
        ),
        ref: Type.Optional(
          Type.String({ description: "Branch, tag, or commit" }),
        ),
      }),
      async execute(_toolCallId, params) {
        const entries = await githubListDirectory(
          params.owner,
          params.repo,
          params.path ?? "",
          params.ref,
        );
        const text =
          entries.length === 0
            ? "Empty directory."
            : entries
                .map(
                  (e) =>
                    `${e.type === "dir" ? "d" : "f"}  ${e.path ?? e.name ?? ""}  ${e.type !== "dir" ? `(${e.size ?? 0}b)` : ""}`,
                )
                .join("\n");
        return {
          content: [{ type: "text", text }],
          details: entries,
        };
      },
    });
  }

  if (enabledMcp("npm-search")) {
    pi.registerTool({
      name: "npm_package_search",
      label: "npm Package Search",
      description: "Search npm registry packages.",
      parameters: Type.Object({
        query: Type.String({ description: "npm search query" }),
        limit: Type.Optional(
          Type.Number({ description: "Maximum results", default: 5 }),
        ),
      }),
      async execute(_toolCallId, params) {
        const url = new URL("https://registry.npmjs.org/-/v1/search");
        url.searchParams.set("text", params.query);
        url.searchParams.set("size", String(params.limit ?? 5));
        const payload = (await fetchJson(url.toString())) as {
          objects?: Array<{
            package?: {
              name?: string;
              version?: string;
              description?: string;
              links?: { npm?: string };
            };
          }>;
        };
        const items = payload.objects ?? [];
        const text =
          items.length === 0
            ? "No results."
            : items
                .map((o, i) => {
                  const p = o.package ?? {};
                  const desc = p.description ? `\n${p.description}` : "";
                  return `[${i + 1}] ${p.name ?? ""}@${p.version ?? ""}${desc}\n${p.links?.npm ?? `https://www.npmjs.com/package/${p.name ?? ""}`}`;
                })
                .join("\n\n");
        return {
          content: [{ type: "text", text }],
          details: payload,
        };
      },
    });

    pi.registerTool({
      name: "npm_package_info",
      label: "npm Package Info",
      description: "Get npm package metadata from registry.",
      parameters: Type.Object({
        packageName: Type.String({ description: "Exact npm package name" }),
        version: Type.Optional(
          Type.String({
            description:
              "Version or dist-tag, e.g. 'latest', '1.0.0'. Defaults to latest.",
          }),
        ),
      }),
      async execute(_toolCallId, params) {
        const encoded = encodeURIComponent(params.packageName);
        const ver = encodeURIComponent(params.version ?? "latest");
        const payload = await fetchJson(
          `https://registry.npmjs.org/${encoded}/${ver}`,
        );
        return {
          content: [{ type: "text", text: JSON.stringify(payload, null, 2) }],
          details: payload,
        };
      },
    });
  }

  if (enabledMcp("pypi")) {
    pi.registerTool({
      name: "pypi_package_info",
      label: "PyPI Package Info",
      description: "Get PyPI package metadata.",
      parameters: Type.Object({
        packageName: Type.String({ description: "Exact PyPI package name" }),
      }),
      async execute(_toolCallId, params) {
        const payload = (await fetchJson(
          `https://pypi.org/pypi/${encodeURIComponent(params.packageName)}/json`,
        )) as {
          info?: {
            name?: string;
            version?: string;
            summary?: string;
            home_page?: string;
            project_urls?: Record<string, string>;
          };
          releases?: Record<string, unknown>;
        };
        const info = payload.info ?? {};
        const recentVersions = Object.keys(payload.releases ?? {})
          .slice(-5)
          .join(", ");
        const text = [
          `${info.name ?? ""}@${info.version ?? ""}`,
          info.summary ?? "",
          info.home_page ? `home: ${info.home_page}` : "",
          info.project_urls?.["Documentation"]
            ? `docs: ${info.project_urls["Documentation"]}`
            : "",
          recentVersions ? `recent versions: ${recentVersions}` : "",
          `https://pypi.org/project/${info.name ?? ""}`,
        ]
          .filter(Boolean)
          .join("\n");
        return {
          content: [{ type: "text", text }],
          details: payload,
        };
      },
    });
  }

  if (enabledMcp("rust-docs")) {
    pi.registerTool({
      name: "crates_search",
      label: "Crates Search",
      description: "Search Rust crates and docs entry points.",
      parameters: Type.Object({
        query: Type.String({ description: "Crate search query" }),
        limit: Type.Optional(
          Type.Number({ description: "Maximum results", default: 5 }),
        ),
      }),
      async execute(_toolCallId, params) {
        const limit = params.limit ?? 5;
        const url = new URL("https://crates.io/api/v1/crates");
        url.searchParams.set("q", params.query);
        url.searchParams.set("per_page", String(limit));
        const payload = (await fetchJson(url.toString(), {
          headers: { "User-Agent": "hva-pi-tools" },
        })) as {
          crates?: Array<{
            name?: string;
            newest_version?: string;
            description?: string;
            downloads?: number;
          }>;
        };
        const crates = payload.crates ?? [];
        const text =
          crates.length === 0
            ? "No results."
            : crates
                .map((c, i) => {
                  const desc = c.description ? `\n${c.description}` : "";
                  return `[${i + 1}] ${c.name ?? ""}@${c.newest_version ?? ""}${desc}\nhttps://crates.io/crates/${c.name ?? ""}`;
                })
                .join("\n\n");
        return {
          content: [{ type: "text", text }],
          details: payload,
        };
      },
    });

    pi.registerTool({
      name: "crates_package_info",
      label: "Crates Package Info",
      description: "Get Rust crate metadata from crates.io.",
      parameters: Type.Object({
        crateName: Type.String({ description: "Exact crate name" }),
      }),
      async execute(_toolCallId, params) {
        const payload = (await cratesPackageInfo(params.crateName)) as {
          crate?: {
            name?: string;
            newest_version?: string;
            description?: string;
            repository?: string;
            documentation?: string;
            downloads?: number;
          };
          versions?: Array<{ num?: string; created_at?: string }>;
        };
        const c = payload.crate ?? {};
        const versions = (payload.versions ?? [])
          .slice(0, 5)
          .map((v) => v.num ?? "")
          .join(", ");
        const text = [
          `${c.name ?? ""}@${c.newest_version ?? ""}`,
          c.description ?? "",
          c.repository ? `repo: ${c.repository}` : "",
          c.documentation
            ? `docs: ${c.documentation}`
            : `docs: https://docs.rs/${c.name ?? ""}`,
          `downloads: ${c.downloads ?? 0}`,
          versions ? `recent versions: ${versions}` : "",
        ]
          .filter(Boolean)
          .join("\n");
        return {
          content: [{ type: "text", text }],
          details: payload,
        };
      },
    });

    pi.registerTool({
      name: "crates_dependencies",
      label: "Crates Dependencies",
      description: "Get Rust crate dependency list from crates.io.",
      parameters: Type.Object({
        crateName: Type.String({ description: "Exact crate name" }),
        version: Type.Optional(
          Type.String({
            description: "Crate version. Defaults to newest_version.",
          }),
        ),
      }),
      async execute(_toolCallId, params) {
        const payload = await cratesDependencies(
          params.crateName,
          params.version,
        );
        return {
          content: [{ type: "text", text: JSON.stringify(payload, null, 2) }],
          details: payload,
        };
      },
    });

    pi.registerTool({
      name: "docs_rs_read",
      label: "docs.rs Read",
      description: "Fetch docs.rs page text for a crate path.",
      parameters: Type.Object({
        crateName: Type.String({ description: "Exact crate name" }),
        version: Type.Optional(
          Type.String({ description: "Crate version. Defaults to latest." }),
        ),
        path: Type.Optional(
          Type.String({
            description: "Docs path under docs.rs, like tokio/fs/",
          }),
        ),
      }),
      async execute(_toolCallId, params) {
        const payload = await docsRsRead(
          params.crateName,
          params.version,
          params.path,
        );
        return {
          content: [
            {
              type: "text",
              text: payload.text.slice(0, 20000) || "Empty response.",
            },
          ],
          details: payload,
        };
      },
    });
  }
}
