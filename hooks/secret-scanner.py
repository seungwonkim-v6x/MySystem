#!/usr/bin/env python3
# Adapted from https://github.com/davila7/claude-code-templates
# Path: cli-tool/components/hooks/security/secret-scanner.py
# Adapted: 2026-05-18 — added fail-open wrapper, MYSYSTEM_HOOKS_ENFORCE gating,
#          dry-run log integration, hard-refuse for private-key headers.
# License: see upstream repo (verify before vendor).
#
# Intercepts `git commit` / `git commit -a` / chained `git add && git commit`
# attempts. Scans staged diff against regexes for common provider keys.
# On match in enforce mode: exit 2 + stderr explains which regex matched.
# On match in dry-run mode: exit 0 + writes to ~/.claude/logs/hook-dry-run.log
# On internal error: exit 0 (fail-open) + writes to ~/.claude/logs/hook-errors.log

import json
import os
import re
import subprocess
import sys
import traceback
from datetime import datetime, timezone

LOG_DIR = os.path.expanduser("~/.claude/logs")
DRY_RUN_LOG = os.path.join(LOG_DIR, "hook-dry-run.log")
ERROR_LOG = os.path.join(LOG_DIR, "hook-errors.log")
HOOK_NAME = "secret-scanner"

# Regexes for known provider keys. Tightened to minimize false positives:
# - OpenAI: requires `T3BlbkFJ` substring (base64 of "OpenAI") which appears
#   in every real key. Generic `sk-XXXX` false-positives on doc placeholders.
# - Anthropic: real keys are ~95 chars; tightened minimum length.
PATTERNS = [
    (r"sk-ant-[A-Za-z0-9_-]{60,}", "Anthropic API key"),
    (r"sk-(proj-)?[A-Za-z0-9]{20,}T3BlbkFJ[A-Za-z0-9]{20,}", "OpenAI API key"),
    (r"AKIA[0-9A-Z]{16}", "AWS access key"),
    (r"aws_secret_access_key\s*=\s*[A-Za-z0-9/+=]{40}", "AWS secret"),
    (r"sk_live_[A-Za-z0-9]{24,}", "Stripe live key"),
    (r"rk_live_[A-Za-z0-9]{24,}", "Stripe restricted live key"),
    (r"gh[pousr]_[A-Za-z0-9]{36,}", "GitHub token"),
    (r"xox[abprs]-[A-Za-z0-9-]{10,}", "Slack token"),
    (r"postgres(ql)?://[^:]+:[^@]+@", "Postgres connection string with password"),
    (r"mysql://[^:]+:[^@]+@", "MySQL connection string with password"),
    (r"mongodb(\+srv)?://[^:]+:[^@]+@", "MongoDB connection string with password"),
    (r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}", "JWT"),
]

# Hard-refuse patterns: blocked even with MYSYSTEM_ALLOW_SECRET_COMMIT=1.
# Patterns are assembled from concatenated literals so the source text of this
# file does not contain the same byte sequence the regex will match (which
# would cause the hook to refuse its own commits). Python concatenates adjacent
# string literals at parse time; the runtime regex is unchanged.
_DASH5 = "-" * 5
_BEGIN = _DASH5 + "BEGIN "
_KEY_TAIL = "KEY" + _DASH5
HARD_REFUSE_PATTERNS = [
    (rf"{_BEGIN}(RSA|EC|DSA|OPENSSH) PRIVATE {_KEY_TAIL}", "private key header"),
    (rf"{_BEGIN}PRIVATE {_KEY_TAIL}", "private key header"),
]


def is_git_commit(command: str) -> bool:
    """Detect `git commit`, `git commit -a`, or chained variants.
    Catches `git -c key=val commit ...` and `git -C path commit ...` bypass forms.
    """
    cmd = re.sub(r"\s+", " ", command.strip())
    return bool(re.search(r"\bgit(\s+(-c\s+\S+|-C\s+\S+))*\s+commit\b", cmd))


def get_staged_diff() -> str:
    """Get staged diff content. Empty string on error."""
    try:
        result = subprocess.run(
            ["git", "diff", "--cached", "--no-color"],
            capture_output=True, text=True, timeout=10,
        )
        return result.stdout if result.returncode == 0 else ""
    except Exception:
        return ""


def scan_for_secrets(diff: str) -> list:
    """Return list of (pattern_name, hard_refuse_bool) for matches."""
    matches = []
    for pattern, name in HARD_REFUSE_PATTERNS:
        if re.search(pattern, diff):
            matches.append((name, True))
    for pattern, name in PATTERNS:
        if re.search(pattern, diff):
            matches.append((name, False))
    return matches


def log_dry_run(reason: str) -> None:
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        with open(DRY_RUN_LOG, "a") as f:
            ts = datetime.now(timezone.utc).isoformat()
            f.write(f"{ts} {HOOK_NAME} WOULD BLOCK: {reason}\n")
    except Exception:
        pass


def main() -> int:
    payload = json.load(sys.stdin)
    canary_log = os.environ.get("MYSYSTEM_HOOK_CANARY_LOG")
    if canary_log:
        try:
            with open(canary_log, "a", encoding="utf-8") as target:
                target.write(f"{HOOK_NAME}\n")
        except OSError:
            pass
    command = payload.get("tool_input", {}).get("command", "")
    if not is_git_commit(command):
        return 0

    diff = get_staged_diff()
    if not diff:
        return 0

    matches = scan_for_secrets(diff)
    if not matches:
        return 0

    hard_refuses = [m for m in matches if m[1]]
    soft_matches = [m for m in matches if not m[1]]

    bypass = os.environ.get("MYSYSTEM_ALLOW_SECRET_COMMIT") == "1"
    enforce = os.environ.get("MYSYSTEM_HOOKS_ENFORCE") == "1"

    # Hard-refuse always blocks (regardless of bypass, regardless of enforce mode).
    if hard_refuses:
        names = ", ".join(m[0] for m in hard_refuses)
        print(f"BLOCKED: {HOOK_NAME} detected hard-refuse pattern (no bypass): {names}", file=sys.stderr)
        return 2

    # Soft matches: bypass overrides, enforce gates.
    if bypass:
        return 0

    reason = ", ".join(m[0] for m in soft_matches)
    if not enforce:
        log_dry_run(reason)
        print(f"[DRY-RUN] {HOOK_NAME} WOULD BLOCK: {reason}", file=sys.stderr)
        return 0

    print(f"BLOCKED: {HOOK_NAME} detected: {reason}. Set MYSYSTEM_ALLOW_SECRET_COMMIT=1 to override for intentional test fixtures.", file=sys.stderr)
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
