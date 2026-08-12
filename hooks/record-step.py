#!/usr/bin/env python3
# Records workflow progress. NEVER denies anything (ADR-0024).
#
# Registered three times:
#   PostToolUse  matcher "Skill"                          — the agent ran a skill
#   PostToolUse  matcher "Write|Edit|MultiEdit|Notebook"  — implementation began
#   UserPromptSubmit                                      — the owner typed something
#
# Both are required. A user-typed `/scope-check` fires NO Skill hook at all
# (measured on CLI 2.1.227), so a recorder listening only to Skill would leave
# the gate denying an owner who actually ran the step.
#
# Recording and enforcement live in separate files on purpose: a bug in the gate
# must not corrupt the record, and a bug here must not block every tool call.

import json
import os
import re
import sys
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mysystem_steps_lib as lib  # noqa: E402

LOG_DIR = os.path.expanduser("~/.claude/logs")
ERROR_LOG = os.path.join(LOG_DIR, "hook-errors.log")
HOOK_NAME = "record-step"

# `gate: off` is the canonical form. The `/gate-off` spelling is kept as an alias
# but does NOT work on its own: Claude Code resolves a leading slash as a command
# and rejects an unknown one with "Unknown command" before the prompt is ever
# submitted, so the hook never sees it. Found by end-to-end test, not by the unit
# tests, which feed the hook directly and skip the CLI's command parsing.
# ANCHORED to the start of the prompt. The previous form matched anywhere, so
# merely discussing the escape hatch armed it: "remind me what gate: off actually
# does" set bypass_prompt_id and `rm -rf src` was then allowed at phase 0. A
# bypass must be a deliberate command, not a phrase that can appear in prose or
# in text the owner pasted from somewhere else.
BYPASS_RE = re.compile(r"^\s*(?:/gate-off|gate:\s*off)\b", re.IGNORECASE)
RESET_RE = re.compile(r"^\s*(?:/gate-reset|gate:\s*reset)\b", re.IGNORECASE)
# A typed slash command: `/scope-check`, optionally with arguments after it.
TYPED_SKILL_RE = re.compile(r"^\s*/([a-z0-9][a-z0-9-]*)")


def known_skill(name: str) -> bool:
    return name in lib.ADVANCING_SKILLS or name in lib.NON_ADVANCING_SKILLS


def handle_prompt(payload: dict) -> None:
    session_id = lib.as_text(payload.get("session_id")) or "unknown"
    prompt_id = payload.get("prompt_id")
    prompt = payload.get("prompt", "") or ""

    state = lib.load(session_id)

    # A new request after /ship starts a fresh cycle.
    if state.get("phase", 0) >= lib.TERMINAL_PHASE or RESET_RE.match(prompt):
        state = lib.blank_state(session_id)

    state["current_prompt_id"] = prompt_id

    if BYPASS_RE.match(prompt):
        # Keyed to this prompt_id, so it expires when the owner's next message
        # arrives. Never an env var: that is how a guard gets disabled forever.
        state["bypass_prompt_id"] = prompt_id

    match = TYPED_SKILL_RE.match(prompt)
    if match and known_skill(match.group(1)):
        lib.record_skill(state, match.group(1), prompt_id)

    lib.save(state)


def handle_skill(payload: dict) -> None:
    session_id = lib.as_text(payload.get("session_id")) or "unknown"
    prompt_id = payload.get("prompt_id")
    skill = (payload.get("tool_input") or {}).get("skill", "")
    if not skill or not known_skill(skill):
        return

    state = lib.load(session_id)
    if prompt_id:
        # Guarded, like handle_write. Assigning None wiped the value handle_prompt
        # recorded and left phase_prompt_id falsy, defeating the same-turn rule.
        state["current_prompt_id"] = prompt_id

    # Guard against double-recording: the typed path already recorded this skill
    # under the same prompt_id when the owner typed it.
    for entry in reversed(state.get("steps", [])):
        if entry.get("skill") == skill and entry.get("prompt_id") == prompt_id:
            lib.save(state)
            return

    lib.record_skill(state, skill, prompt_id)
    lib.save(state)


def handle_write(payload: dict) -> None:
    """A completed write after /autoplan means implementation is under way."""
    session_id = lib.as_text(payload.get("session_id")) or "unknown"
    state = lib.load(session_id)
    if payload.get("prompt_id"):
        state["current_prompt_id"] = payload["prompt_id"]
    lib.record_write(state)
    lib.save(state)


def main() -> int:
    payload = json.load(sys.stdin)
    if not isinstance(payload, dict):
        return 0

    canary = os.environ.get("MYSYSTEM_HOOK_CANARY_LOG")
    if canary:
        try:
            with open(canary, "a", encoding="utf-8") as fh:
                fh.write(f"{HOOK_NAME}\n")
        except OSError:
            pass

    event = payload.get("hook_event_name", "")
    if event == "UserPromptSubmit":
        handler = handle_prompt
    elif payload.get("tool_name") == "Skill":
        handler = handle_skill
    elif payload.get("tool_name") in lib.WRITE_TOOLS:
        handler = handle_write
    else:
        return 0

    # Every handler is a read-modify-write on one marker, and parallel tool calls
    # make two of them concurrent. Without this the two Step-6 review passes lose
    # one entry and /ship never unlocks.
    session = lib.as_text(payload.get("session_id")) or "unknown"
    with lib.locked(session) as held:
        if not held:
            # The lock timed out or could not be taken. Say so: silently running
            # the read-modify-write unlocked is how a step goes missing.
            print("[record-step] proceeding without the marker lock", file=sys.stderr)
        handler(payload)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # fail-open: recording must never block work
        try:
            os.makedirs(LOG_DIR, exist_ok=True)
            with open(ERROR_LOG, "a", encoding="utf-8") as fh:
                fh.write(f"{lib.now()} {HOOK_NAME} ERROR: {exc}\n{traceback.format_exc()}\n")
        except Exception:
            pass
        sys.exit(0)
