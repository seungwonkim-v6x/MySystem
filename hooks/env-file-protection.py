#!/usr/bin/env python3
# Adapted from https://github.com/davila7/claude-code-templates
# Path: cli-tool/components/hooks/security/env-file-protection.json
# Adapted: 2026-05-18 — rewritten as Python script (upstream uses Claude Code
#          conditional matcher syntax `Write(.env*)` which we replaced with
#          portable Python check on file_path). Added fail-open wrapper,
#          MYSYSTEM_HOOKS_ENFORCE gating, dry-run log integration.
# License: see upstream repo (verify before vendor).
#
# Blocks Write / Edit / MultiEdit on any .env, .env.local, .env.production, etc.
# No bypass env var. Manual shell edit only for legitimate .env changes.

import json
import os
import re
import sys
import traceback
from datetime import datetime, timezone

LOG_DIR = os.path.expanduser("~/.claude/logs")
DRY_RUN_LOG = os.path.join(LOG_DIR, "hook-dry-run.log")
ERROR_LOG = os.path.join(LOG_DIR, "hook-errors.log")
HOOK_NAME = "env-file-protection"

# Match any path ending in .env or .env.<suffix1>.<suffix2>...
# Real-world frameworks use .env.production.local, .env.development.local, etc.
# Pattern stored as string; compiled lazily inside main() so a malformed regex
# from a future edit fails inside try/except (fail-open) rather than at import.
ENV_PATTERN_STR = r"(^|/)\.env(\.[A-Za-z0-9_-]+)*$"


def log_dry_run(file_path: str) -> None:
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        with open(DRY_RUN_LOG, "a") as f:
            ts = datetime.now(timezone.utc).isoformat()
            f.write(f"{ts} {HOOK_NAME} WOULD BLOCK: write to {file_path}\n")
    except Exception:
        pass


def main() -> int:
    payload = json.load(sys.stdin)
    tool_input = payload.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    if not file_path:
        return 0

    if not re.search(ENV_PATTERN_STR, file_path):
        return 0

    enforce = os.environ.get("MYSYSTEM_HOOKS_ENFORCE") == "1"

    if not enforce:
        log_dry_run(file_path)
        print(f"[DRY-RUN] {HOOK_NAME} WOULD BLOCK: write to {file_path}", file=sys.stderr)
        return 0

    print(f"BLOCKED: {HOOK_NAME} refuses to write to {file_path}. Edit .env files manually via shell.", file=sys.stderr)
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
