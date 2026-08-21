import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { realpathSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, isAbsolute, relative, resolve, sep } from "node:path";

type ToolCallContext = {
  cwd: string;
  hasUI: boolean;
  ui: { confirm(title: string, body: string): Promise<boolean>; notify(message: string, level: "info" | "warning" | "error"): void };
};

type ToolCallEvent = {
  toolName: string;
  input: Record<string, unknown>;
};

function canonicalPath(cwd: string, value: string): string {
  const expanded = value === "~" ? homedir() : value.startsWith("~/") ? `${homedir()}${value.slice(1)}` : value;
  const candidate = resolve(cwd, expanded);
  const suffix: string[] = [];
  let probe = candidate;

  while (true) {
    try {
      return resolve(realpathSync(probe), ...suffix.reverse());
    } catch {
      const parent = dirname(probe);
      if (parent === probe) return candidate;
      suffix.push(basename(probe));
      probe = parent;
    }
  }
}

function under(path: string, parent: string): boolean {
  const child = relative(parent, path);
  return child === "" || (child !== ".." && !child.startsWith(`..${sep}`) && !isAbsolute(child));
}

function protectedPathReason(cwd: string, rawPath: string): string | undefined {
  if (!rawPath || rawPath.startsWith("-")) return undefined;
  const path = canonicalPath(cwd, rawPath);
  const parts = path.split(sep);
  const file = basename(path).toLowerCase();
  const home = homedir();

  if (parts.includes(".git")) return "writes to .git are never allowed";
  if (parts.includes("node_modules")) return "writes to node_modules are disabled";
  if (/^\.env(?:\..+)?$/i.test(file)) return "environment files are protected";
  if (/\.(?:pem|key|p12|pfx)$/i.test(file)) return "private-key material is protected";
  if (under(path, `${home}/.ssh`) || under(path, `${home}/.aws`)) return "credential directories are protected";
  if (
    file === "auth.json" ||
    file === ".credentials.json" ||
    under(path, `${home}/.pi/agent`) ||
    under(path, `${home}/.codex`)
  ) {
    return "runtime authentication files are protected";
  }
  return undefined;
}

const hardCommandRules: Array<[RegExp, string]> = [
  [/\brm\s+(?:-[^\s]+\s+)+\/(?:\s|$)/i, "recursive removal of a system path"],
  [/\brm\s+(?:-[^\s]+\s+)+(?:~|\$HOME)(?:\/|\s|$)/i, "recursive removal of the home directory"],
  [/\bdd\b[^\n]*\bof=\/dev\//i, "raw disk/device overwrite"],
  [/\bmkfs(?:\.[\w-]+)?\s+\/dev\//i, "filesystem formatting on a device"],
  [/:\(\)\s*\{\s*:\|:/, "fork bomb"],
  [/\b(?:curl|wget)\b[^\n]*\|\s*(?:bash|sh|zsh)\b/i, "piping downloaded content into a shell"],
  [/\bgit\s+commit\b[^\n]*(?:--no-verify|\s-n(?:\s|$))/i, "bypassing git verification hooks"],
  [/(?:\bgit\s+push\b[^\n]*(?:--force|-f)\b[^\n]*\b(?:main|master)\b|\bgit\s+push\b[^\n]*\b(?:main|master)\b[^\n]*(?:--force|-f)\b)/i, "force-pushing a protected branch"],
  [/(?:>|>>|\btee\b)[^\n]*(?:\.env(?:[./\s]|$)|\.git(?:[\/\s]|$)|(?:auth|credentials)\.json)/i, "writing protected configuration or credential material"],
  [/\brm\b[^\n]*(?:\.env(?:[./\s]|$)|\.git(?:[\/\s]|$)|(?:auth|credentials)\.json)/i, "removing protected configuration or credential material"],
];

const confirmationRules: Array<[RegExp, string]> = [
  [/\bsudo\b/i, "sudo command"],
  [/\brm\s+-[^\n]*r/i, "recursive removal"],
  [/\bgit\s+(?:commit|push|reset\s+--hard|clean\s+-[^\n]*f|merge|rebase)\b/i, "git history or remote mutation"],
  [/\bgh\s+(?:pr|release)\s+(?:create|merge|close|delete)\b/i, "GitHub publication or mutation"],
  [/\b(?:curl|wget)\b[^\n]*(?:--data(?:-raw)?|\s-X\s*(?:POST|PUT|PATCH|DELETE)\b)/i, "outbound network mutation"],
];

function preview(command: string): string {
  const compact = command.replace(/\s+/g, " ").trim();
  return compact.length > 500 ? `${compact.slice(0, 497)}...` : compact;
}

export default function piSafety(pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    const typedEvent = event as unknown as ToolCallEvent;
    const typedContext = ctx as unknown as ToolCallContext;

    if (typedEvent.toolName === "write" || typedEvent.toolName === "edit") {
      const path = String(typedEvent.input.path ?? "");
      const reason = protectedPathReason(typedContext.cwd, path);
      if (reason) {
        if (typedContext.hasUI) typedContext.ui.notify(`Blocked ${path}: ${reason}`, "warning");
        return { block: true, reason };
      }
      return undefined;
    }

    if (typedEvent.toolName !== "bash") return undefined;
    const command = String(typedEvent.input.command ?? "");

    for (const [pattern, reason] of hardCommandRules) {
      if (pattern.test(command)) {
        if (typedContext.hasUI) typedContext.ui.notify(`Blocked: ${reason}`, "error");
        return { block: true, reason: `Pi safety guard: ${reason}` };
      }
    }

    const confirmation = confirmationRules.find(([pattern]) => pattern.test(command));
    if (!confirmation) return undefined;
    const [, label] = confirmation;
    if (!typedContext.hasUI) {
      return { block: true, reason: `Pi safety guard requires interactive confirmation for ${label}` };
    }

    const allowed = await typedContext.ui.confirm(
      `Confirm ${label}`,
      `${preview(command)}\n\nAllow this command?`,
    );
    return allowed ? undefined : { block: true, reason: "Cancelled by user" };
  });
}
