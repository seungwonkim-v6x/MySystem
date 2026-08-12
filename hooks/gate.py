#!/usr/bin/env python3
# The workflow gate: default-deny by phase (ADR-0024).
#
# PreToolUse, matcher "*". Reads the step marker, computes what the current phase
# allows, and denies everything else. No heuristics, no scoring, no "does this
# look like implementation" judgment — the tool call is in the phase's allowlist
# or it is not.
#
# Why default-deny rather than a list of forbidden things: every attempt to
# enumerate dangerous actions leaks. gstack's own /careful hook has been patched
# repeatedly for exactly this (BSD capital -R, then command substitution ending
# in an allowlisted suffix). Default-deny fails the other way — it blocks
# legitimate work, which is visible and recoverable via /gate-off, instead of
# silently permitting a skipped step, which is the failure being fixed.
#
# Blocking uses JSON `permissionDecision: "deny"` rather than exit 2 because
# that is the form measured to hold under --dangerously-skip-permissions, and to
# win over another hook's "allow" (2026-08-11, CLI 2.1.227).
#
# Set MYSYSTEM_GATE_DRYRUN=1 to log decisions without enforcing. Enforcement is
# the DEFAULT here, unlike the safety hooks: this gate shapes workflow rather
# than adjudicating risk, and the owner asked for it to bind.

import json
import os
import sys
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mysystem_steps_lib as lib  # noqa: E402

LOG_DIR = os.path.expanduser("~/.claude/logs")
ERROR_LOG = os.path.join(LOG_DIR, "hook-errors.log")
HOOK_NAME = "gate"


def emit_allow() -> None:
    print("{}")


def emit_deny(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": f"[workflow gate] {reason}",
        }
    }))


def main() -> int:
    payload = json.load(sys.stdin)
    if not isinstance(payload, dict):
        # A non-object payload used to crash into the fail-open path, allowing
        # everything. Treat it as empty and fall through to the ungated branch.
        payload = {}

    canary = os.environ.get("MYSYSTEM_HOOK_CANARY_LOG")
    if canary:
        try:
            with open(canary, "a", encoding="utf-8") as fh:
                fh.write(f"{HOOK_NAME}\n")
        except OSError:
            pass

    session_id = lib.as_text(payload.get("session_id")) or "unknown"
    tool_name = payload.get("tool_name", "")
    # Every payload field used below must be hashable/str-safe. `tool_name in
    # WRITE_TOOLS` on a list raised TypeError while BUILDING THE LOG ENTRY, after
    # decide() had already returned a deny, and the crash handler then emitted an
    # allow. That is the third time this exact shape appeared: a deny computed
    # correctly and then lost to an exception on the way to the log.
    log_tool = tool_name if isinstance(tool_name, str) else repr(tool_name)
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        # Normalised HERE, not only inside decide(). Review found that a
        # `tool_input` of "hello" or 42 crashed the log_decision call below —
        # after the deny had been computed — and the fail-open handler then turned
        # that deny into an allow. Exactly the bug class the robustness suite
        # exists to close; it shipped because the test helper read a stale log
        # line (see tests/helpers/gate.bash).
        tool_input = {}

    state = lib.load(session_id)
    # Trust the payload's prompt_id over the recorder's copy: it is authoritative
    # for this call and removes any dependency on hook execution order, which
    # Claude Code does not guarantee ("All matching hooks run in parallel").
    if payload.get("prompt_id"):
        state["current_prompt_id"] = payload["prompt_id"]

    decision, reason, rule = lib.decide(state, tool_name, tool_input,
                                        payload.get("cwd"))

    lib.log_decision({
        "session_id": session_id,
        "prompt_id": payload.get("prompt_id"),
        "phase": state.get("phase", 0),
        "tool": log_tool,
        "skill": tool_input.get("skill") if log_tool == "Skill" else None,
        "path": tool_input.get("file_path") if log_tool in lib.WRITE_TOOLS else None,
        "decision": decision,
        "rule": rule,
        "reason": reason,
        "dry_run": os.environ.get("MYSYSTEM_GATE_DRYRUN") == "1",
    })

    if decision == "deny":
        if os.environ.get("MYSYSTEM_GATE_DRYRUN") == "1":
            print(f"[DRY-RUN] {HOOK_NAME} WOULD DENY: {reason}", file=sys.stderr)
            emit_allow()
            return 0
        emit_deny(reason)
        return 0

    emit_allow()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        # Fail-open on a CRASH only. Deliberate denials (unparseable Bash, wrong
        # phase) are decisions and are returned above; this path exists so a bug
        # in the gate cannot brick a session.
        try:
            os.makedirs(LOG_DIR, exist_ok=True)
            with open(ERROR_LOG, "a", encoding="utf-8") as fh:
                fh.write(f"{lib.now()} {HOOK_NAME} ERROR: {exc}\n{traceback.format_exc()}\n")
        except Exception:
            pass
        print("{}")
        sys.exit(0)
