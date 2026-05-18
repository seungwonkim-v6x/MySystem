#!/usr/bin/env python3
# Adapted from https://github.com/davila7/claude-code-templates
# Path: cli-tool/components/hooks/security/dangerous-command-blocker.py
# Adapted: 2026-05-18 — added fail-open wrapper, MYSYSTEM_HOOKS_ENFORCE gating,
#          dry-run log integration.
# License: see upstream repo (verify before vendor).
#
# Blocks catastrophic Bash commands: rm -rf /, dd, mkfs, writes to .git/ or .claude/,
# suspicious patterns. No bypass env var — these are unconditional refuses in enforce mode.
# In dry-run mode: exit 0 + log to ~/.claude/logs/hook-dry-run.log
# On internal error: exit 0 (fail-open) + log to ~/.claude/logs/hook-errors.log

import json
import os
import re
import sys
import traceback
from datetime import datetime, timezone

LOG_DIR = os.path.expanduser("~/.claude/logs")
DRY_RUN_LOG = os.path.join(LOG_DIR, "hook-dry-run.log")
ERROR_LOG = os.path.join(LOG_DIR, "hook-errors.log")
HOOK_NAME = "dangerous-command-blocker"

# Computed at module load: absolute home path for absolute-path .claude/ matching.
# Wrapped in try so module load itself never fails (fail-open extends to imports).
try:
    _HOME = os.path.expanduser("~")
except Exception:
    _HOME = "/Users"  # safe default; pattern still matches the prefix

# (regex, human-readable reason). All matches block unconditionally in enforce mode.
# Robust rm matching: require at least one `r` or `R` AND one `f` somewhere in the
# flag region (handles `-rf`, `-fr`, `-fR`, `-Rf`, `-r -f`, `-f -R`, etc.). Path
# match accepts quoted ("/etc") or unquoted forms; whitelist /tmp, /var/folders,
# /dev/null, and relative paths.
PATTERNS = [
    # rm with recursive + force on absolute system path (combined flags)
    (r"\brm\s+(-[a-zA-Z]*[rR][a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*[rR])\s+[\"']?/(?!tmp/|private/tmp/|var/folders/|dev/null)",
     "rm -rf on a system path (combined flags)"),
    # rm with recursive + force on absolute system path (separated flags, either order)
    (r"\brm\s+(-[rR]\s+-[a-zA-Z]*f|-[a-zA-Z]*f\s+-[rR])\s+[\"']?/(?!tmp/|private/tmp/|var/folders/|dev/null)",
     "rm with -r and -f separated on a system path"),
    (r"\brm\s+(-[rR]f|-f[rR]|-[rR]\s+-f|-f\s+-[rR])\s+\$HOME\b", "rm -rf $HOME"),
    (r"\brm\s+(-[rR]f|-f[rR]|-[rR]\s+-f|-f\s+-[rR])\s+~(\s|$|/)", "rm -rf ~"),
    # Also match the same patterns inside bash -c "..." / sh -c '...' wrappers
    (r"\b(bash|sh|zsh)\s+-c\s+[\"'][^\"']*\brm\s+(-[a-zA-Z]*[rR][a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*[rR])\s+[\"']?/(?!tmp/|private/tmp/|var/folders/|dev/null)",
     "rm -rf on a system path (inside bash -c / sh -c)"),
    # dd writing to a device (raw disk overwrite)
    (r"\bdd\s+.*of=/dev/[sh]d[a-z]", "dd to a block device"),
    (r"\bdd\s+.*of=/dev/disk", "dd to a block device"),
    # mkfs (format filesystem)
    (r"\bmkfs(\.[a-z0-9]+)?\s+/dev/", "mkfs on a device"),
    # shred / wipe
    (r"\bshred\s+.*-[a-zA-Z]*u", "shred -u (overwrite + delete)"),
    # Writes to .git/ internals (corrupts repo)
    (r"(>|>>)\s*\.git/", "redirect into .git/"),
    (r"\brm\s+.*\.git/(HEAD|index|refs|objects)", "delete git internals"),
    # Writes to .claude/ (corrupts harness config) — covers ~, $HOME, AND absolute
    (r"(>|>>)\s*~/\.claude/", "redirect into ~/.claude/"),
    (r"(>|>>)\s*\$HOME/\.claude/", "redirect into $HOME/.claude/"),
    (rf"(>|>>)\s*{re.escape(_HOME)}/\.claude/", "redirect into ~/.claude/ (absolute path)"),
    (r"(>|>>)\s*/Users/[^/\s]+/\.claude/", "redirect into another user's .claude/ (absolute path)"),
    # Fork bomb
    (r":\(\)\s*\{\s*:\|:", "fork bomb"),
    # Curl piped to shell from unknown URL (only block if not a known-good domain)
    # Conservative: just flag curl|bash; user can override by saving the script first.
    (r"\bcurl\s+[^|]*\|\s*(bash|sh|zsh|fish)\b", "curl piped to shell"),
]


def scan(command: str) -> list:
    """Return list of human-readable reasons for matches."""
    return [reason for pattern, reason in PATTERNS if re.search(pattern, command)]


def log_dry_run(command: str, reasons: list) -> None:
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        with open(DRY_RUN_LOG, "a") as f:
            ts = datetime.now(timezone.utc).isoformat()
            cmd_preview = command[:200].replace("\n", " ")
            f.write(f"{ts} {HOOK_NAME} WOULD BLOCK: {', '.join(reasons)} | cmd: {cmd_preview}\n")
    except Exception:
        pass


def main() -> int:
    payload = json.load(sys.stdin)
    command = payload.get("tool_input", {}).get("command", "")
    if not command:
        return 0

    reasons = scan(command)
    if not reasons:
        return 0

    enforce = os.environ.get("MYSYSTEM_HOOKS_ENFORCE") == "1"
    msg = ", ".join(reasons)

    if not enforce:
        log_dry_run(command, reasons)
        print(f"[DRY-RUN] {HOOK_NAME} WOULD BLOCK: {msg}", file=sys.stderr)
        return 0

    print(f"BLOCKED: {HOOK_NAME} refused command: {msg}. No bypass available; perform this action via Finder/UI/shell directly if intentional.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        try:
            os.makedirs(LOG_DIR, exist_ok=True)
            with open(ERROR_LOG, "a") as f:
                ts = datetime.now(timezone.utc).isoformat()
                f.write(f"{ts} {HOOK_NAME} ERROR: {e}\n{traceback.format_exc()}\n")
        except Exception:
            pass
        sys.exit(0)  # fail-open
