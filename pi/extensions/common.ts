export function splitCsv(value: string | undefined): string[] {
  return (value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

export function envEnabled(name: string, enabledVar: string, disabledVar: string): boolean {
  const enabled = splitCsv(process.env[enabledVar]);
  const disabled = splitCsv(process.env[disabledVar]);
  if (enabled.length > 0 || disabled.length > 0) {
    return enabled.includes(name) && !disabled.includes(name);
  }
  return false;
}

export function enabledMcp(name: string): boolean {
  return envEnabled(name, "HVA_MCP_ENABLED", "HVA_MCP_DISABLED");
}
