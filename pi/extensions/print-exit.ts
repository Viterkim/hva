import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("session_shutdown", () => {
    const delayMs = Number.parseInt(process.env.HVA_PI_PRINT_EXIT_DELAY_MS ?? "50", 10);
    setTimeout(() => {
      process.exit(process.exitCode ?? 0);
    }, Number.isFinite(delayMs) && delayMs >= 0 ? delayMs : 50);
  });
}
