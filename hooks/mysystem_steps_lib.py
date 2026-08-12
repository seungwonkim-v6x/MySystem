#!/usr/bin/env python3
# Shared state + policy for the workflow gate (ADR-0024).
#
# Imported by hooks/record-step.py, hooks/gate.py and scripts/mysystem-steps.
# Holds no I/O policy of its own beyond the marker file: the callers decide
# whether to deny.
#
# Design notes that are load-bearing (measured 2026-08-11, CLI 2.1.227):
#   - `Skill` DOES fire PreToolUse/PostToolUse and carries tool_input.skill,
#     prompt_id and session_id. Vendor docs say otherwise and are wrong.
#   - A USER-TYPED `/skill` fires no Skill hook at all, so the recorder must
#     also read UserPromptSubmit or the gate denies an owner who complied.
#   - A JSON `permissionDecision: "deny"` wins over another hook's "allow" and
#     holds under bypassPermissions / --dangerously-skip-permissions.

import json
import os
import re
import shlex
import tempfile
import time
from contextlib import contextmanager
from datetime import datetime, timezone

STATE_HOME = os.environ.get("MYSYSTEM_STATE_HOME") or os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "mysystem",
)
STEPS_DIR = os.path.join(STATE_HOME, "steps")
GATE_LOG = os.path.join(STATE_HOME, "gate-log.jsonl")

# --- Workflow model -------------------------------------------------------
#
# `phase` is the highest workflow step completed in this request cycle.
# Step numbering follows CLAUDE.md, including the deliberate gap at 7.

# Skills that ADVANCE the workflow, mapped to the phase they advance to.
ADVANCING_SKILLS = {
    "scope-check": 1,
    "office-hours": 1,
    "investigate": 1,
    "deep-research": 2,
    "autoplan": 3,
    "verify-test": 5,
    "qa-only": 5,
    "design-review": 5,
    "review": 6,
    "requesting-code-review": 6,
    "ship": 7,
}

# Skills allowed at a phase without advancing it: augments and browser layers.
# `verification-before-completion` is the Step-5 augment and `aside-qa` is the
# browser layer, so neither is a step on its own.
NON_ADVANCING_SKILLS = {
    "verification-before-completion": 4,
    "aside-qa": 4,
    "frontend-design": 3,
}

# Step 6 requires BOTH review passes (CLAUDE.md: "both must complete before the
# gate"), so reaching phase 6 is a conjunction, not a single skill.
STEP6_REQUIRED = {"review", "requesting-code-review"}

# Minimum phase at which each capability unlocks.
WRITE_UNLOCK_PHASE = 3          # /autoplan must be done before code is written
                                # (enforcing for the write TOOLS; advisory vs Bash)
PUBLISH_UNLOCK_PHASE = 6        # commit/push/PR only after the review gate
TERMINAL_PHASE = 7

WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}

# Tools that are never gated. Read-only inspection must stay free at phase 0,
# or Step 1 would have to be answered blind.
ALWAYS_ALLOWED_TOOLS = {
    "Read", "Glob", "Grep", "TodoWrite", "AskUserQuestion", "WebSearch",
    "WebFetch", "ListAgents", "SendUserFile", "Skill", "Task", "TaskCreate",
    "TaskGet", "TaskList", "TaskOutput", "TaskStop", "TaskUpdate", "Monitor",
    "ToolSearch", "EnterPlanMode", "ExitPlanMode", "ReportFindings",
    "ScheduleWakeup", "Artifact",
}

# Bash is NOT gated at all (ADR-0024, amended twice after review).
#
# Round 1 gated it behind a read-only allowlist; review walked through five write
# paths. Round 2 kept a publishing-only gate; review walked through six more —
# `sh -c 'git commit'`, `env git push`, `(git push)`, `git -c alias.x=push x`,
# `git revert`, and `gh api -f …` (gh defaults to POST when a field is present).
#
# Both rounds failed the same way: a predicate over an open-ended space, written
# by the author, believed complete. A command prefix, a subshell, or an alias
# defeats any such predicate, and `sh -c` defeats all of them at once. So the
# predicate is deleted rather than sharpened a third time.
#
# What survived three review rounds untouched is the enforcing core, and that is
# all this gate now claims: skill ORDER, the TURN BOUNDARY, and denying the write
# TOOLS before phase 3. Everything a reviewer broke was something added around it.

# Split a command line into segments that could each be a separate command.
# A lone `&` backgrounds and starts a new one, but `&` inside `2>&1`, `>&2` or
# `&>file` belongs to a redirection.
SPLIT_RE = re.compile(r"&&|\|\||;|\n|\||(?<![>&\d])&(?![>&])")

# Paths writable in any phase, resolved with realpath and confined to the repo.
#
# Round 1 matched `docs/` anywhere in an unnormalised path, so `docs/../hooks/gate.py`
# was writable. Round 2 used normpath, so a SYMLINK laundered it — review pointed
# `docs/notes.md` at `hooks/gate.py` and overwrote the gate. And a blanket `\.md$`
# made `~/.claude/skills/**/SKILL.md` writable, which is not documentation: it is
# instructions this agent executes.
#
# So: resolve symlinks, require the real path to sit inside the invoking repo, and
# name the files exactly rather than matching an extension.
DOCS_DIR_NAMES = ("docs",)
DOCS_FILE_NAMES = ("CHANGELOG.md", "VERSION", "TODOS.md", "CONTEXT.md", ".gitignore")


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


# --- Marker file ---------------------------------------------------------

def state_path(session_id: str) -> str:
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", session_id or "unknown")
    return os.path.join(STEPS_DIR, f"{safe}.json")


def blank_state(session_id: str) -> dict:
    return {
        "session_id": session_id,
        "current_prompt_id": None,
        "phase": 0,
        "phase_prompt_id": None,
        "steps": [],
        "bypass_prompt_id": None,
    }


def load(session_id: str) -> dict:
    """Read the marker, sanitising every field.

    Sanitising is load-bearing, not defensive politeness. The gate fails OPEN on a
    crash so a bug cannot brick a session, which means any TypeError raised while
    reading a malformed marker would silently DISABLE enforcement — the worst
    failure this design has. Throwaway testing found exactly that via a marker
    holding `[1,2,3]`, a `phase` of `"3"`, and a numeric `file_path`. So nothing
    from disk is trusted to have the type it should.
    """
    try:
        with open(state_path(session_id), encoding="utf-8") as fh:
            state = json.load(fh)
    except (OSError, ValueError):
        return blank_state(session_id)

    base = blank_state(session_id)
    if not isinstance(state, dict):
        return base
    base.update(state)

    phase = base.get("phase")
    if isinstance(phase, bool) or not isinstance(phase, int):
        phase = 0
    base["phase"] = max(0, min(TERMINAL_PHASE, phase))

    if not isinstance(base.get("steps"), list):
        base["steps"] = []
    base["steps"] = [s for s in base["steps"] if isinstance(s, dict)]

    for key in ("current_prompt_id", "phase_prompt_id", "bypass_prompt_id"):
        if base.get(key) is not None and not isinstance(base[key], str):
            base[key] = None
    return base


def as_text(value) -> str:
    """Coerce a tool-input field to str. A non-string must not raise into the
    fail-open path, where it would read as permission."""
    if isinstance(value, str):
        return value
    if value is None:
        return ""
    return str(value)


def save(state: dict) -> None:
    os.makedirs(STEPS_DIR, exist_ok=True)
    target = state_path(state.get("session_id", "unknown"))
    fd, tmp = tempfile.mkstemp(dir=STEPS_DIR, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(state, fh, indent=1, sort_keys=True)
        os.replace(tmp, target)   # atomic swap: a reader never sees a torn file
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


@contextmanager
def locked(session_id: str, timeout: float = 2.0):
    """Serialise read-modify-write on one session's marker.

    An earlier version claimed "single writer per session, so no locking" and that
    was WRONG. The model can emit several tool calls in one message, so two
    PostToolUse hooks run concurrently, and `load(); mutate; save()` then loses an
    update. Reproduced with the two Step-6 review passes, which CLAUDE.md
    explicitly says to launch concurrently: one `steps` entry vanished, the phase
    stayed at 5, and `/ship` never unlocked.

    mkdir is the atomic primitive rather than flock, matching the portability fix
    this repo already made in v0.39.0. On timeout we proceed WITHOUT the lock:
    recording must never block work, and a lost update is strictly better than a
    session that cannot record at all.
    """
    os.makedirs(STEPS_DIR, exist_ok=True)
    lock = state_path(session_id) + ".lock"
    deadline = time.monotonic() + timeout
    held = False
    while True:
        try:
            os.mkdir(lock)
            nonce = f"{os.getpid()}-{time.monotonic_ns()}"
            with open(os.path.join(lock, "owner"), "w", encoding="utf-8") as fh:
                fh.write(nonce)
            held = True
            break
        except FileExistsError:
            # Reclaim a lock abandoned by a killed process — but SERIALISE the
            # reclaim. The staleness check and the removal are not atomic with
            # respect to each other, so several contenders that all saw the lock
            # as stale would each go on to remove whatever sat at that path,
            # including a brand-new LIVE lock a peer had just created. Measured at
            # 120 mutual-exclusion violations in 400 trials with 4 contenders
            # (the normal, non-stale path measured 0/400 both before and after).
            # An O_EXCL marker lets exactly one contender perform the reclaim.
            try:
                if time.time() - os.stat(lock).st_mtime > 30:
                    claim = lock + ".reclaim"
                    try:
                        fd = os.open(claim, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
                        os.close(fd)
                    except FileExistsError:
                        time.sleep(0.01)
                        continue                  # a peer is already reclaiming
                    try:
                        for leaf in os.listdir(lock):
                            os.unlink(os.path.join(lock, leaf))
                        os.rmdir(lock)
                    finally:
                        os.unlink(claim)
                    continue
            except OSError:
                pass
            if time.monotonic() >= deadline:
                break
            time.sleep(0.01)
        except OSError:
            break
    try:
        yield held
    finally:
        if held:
            # Release only if we still own it — a reclaim may have taken it.
            try:
                with open(os.path.join(lock, "owner"), encoding="utf-8") as fh:
                    mine = fh.read() == nonce
                if mine:
                    os.unlink(os.path.join(lock, "owner"))
                    os.rmdir(lock)
            except OSError:
                pass


def log_decision(entry: dict) -> None:
    """Append one gate decision. Never raises — a full disk must not block work."""
    try:
        os.makedirs(STATE_HOME, exist_ok=True)
        entry = dict(entry)
        entry["ts"] = now()
        with open(GATE_LOG, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, sort_keys=True) + "\n")
    except Exception:
        pass


# --- Recording -----------------------------------------------------------

def skill_step(skill: str):
    """Phase this skill advances to, or None if it does not advance."""
    return ADVANCING_SKILLS.get(skill)


def record_skill(state: dict, skill: str, prompt_id) -> dict:
    """Record a skill invocation and advance the phase when it earns one.

    The ordering predicate is applied HERE as well as in decide(), because a
    user-typed `/skill` arrives via UserPromptSubmit and never passes through
    PreToolUse. Review showed a session whose first prompt was `/autoplan` jumping
    straight to phase 3 with steps 1 and 2 never run, unlocking writes.
    """
    target = skill_step(skill)
    if target is None:
        state["steps"].append({"skill": skill, "prompt_id": prompt_id, "ts": now()})
        return state
    if not _advancing_phase_ok(skill, state.get("phase", 0)):
        # Rejected out-of-order steps are NOT recorded. Appending first let a
        # typed `/review` from any earlier turn satisfy the Step-6 conjunction,
        # so publishing unlocked with one review pass instead of two.
        return state
    state["steps"].append({"skill": skill, "prompt_id": prompt_id, "ts": now()})

    if target == 6:
        seen = {s.get("skill") for s in state["steps"]}
        if not STEP6_REQUIRED.issubset(seen):
            # One pass of the two-pass review is not the step.
            return state

    if target > state["phase"]:
        state["phase"] = target
        # Fall back to the turn's prompt_id when the payload carried none.
        # Stamping None left phase_prompt_id falsy, and the same-turn check is
        # `if state.get("phase_prompt_id") and ...`, so the turn boundary opened.
        state["phase_prompt_id"] = prompt_id or state.get("current_prompt_id")
    return state


# --- Policy --------------------------------------------------------------

def is_docs_path(path, cwd=None) -> bool:
    """True for documentation inside the invoking repo, symlinks resolved."""
    text = as_text(path)
    if not text:
        return False
    base = as_text(cwd) or os.getcwd()
    try:
        real = os.path.realpath(os.path.join(base, text))
        root = os.path.realpath(base)
    except (OSError, ValueError):
        return False
    if os.path.commonpath([real, root]) != root:
        return False                     # outside the repo: never a docs write
    rel = os.path.relpath(real, root)
    head = rel.split(os.sep)[0]
    return head in DOCS_DIR_NAMES or rel in DOCS_FILE_NAMES


def split_bash_segments(command):
    """Split on every operator that can start a new command.

    Returns (segments, parse_ok). parse_ok is False when the command cannot be
    tokenised, and the caller must then DENY: failing closed on unparseable
    input is the whole point of the allowlist design (SPEC §2).
    """
    command = as_text(command)
    if not command.strip():
        return [], True
    if "$(" in command or "`" in command or "<(" in command:
        # Command substitution can hide anything, including a write that ends in
        # an allowlisted token. gstack's /careful was patched for exactly this
        # (`rm -rf $(./wipe-all)/node_modules`). Refuse rather than guess.
        return [], False
    parts = SPLIT_RE.split(command)
    segments = []
    for part in parts:
        part = part.strip()
        if not part:
            continue
        try:
            tokens = shlex.split(part)
        except ValueError:
            return [], False
        if tokens:
            segments.append(tokens)
    return segments, True


def is_publishing(tokens) -> bool:
    """True when this segment publishes: commit, push, tag, PR, release.

    Scans past global options instead of trusting tokens[1]. Review found that
    `git -C . commit`, `git -c user.name=x commit`, `git --no-pager push` and
    `gh api -X POST .../pulls` all sailed through the review gate because only
    tokens[1] was inspected.
    """
    if not tokens:
        return False
    argv0 = os.path.basename(as_text(tokens[0]))
    subs = PUBLISH_SUBCOMMANDS.get(argv0)
    if not subs:
        return False
    i = 1
    while i < len(tokens):
        token = as_text(tokens[i])
        if token in GIT_VALUE_OPTS:
            i += 2                      # option plus its value
            continue
        if token.startswith("-"):
            i += 1                      # flag with no separate value
            continue
        if token not in subs:
            return False
        if argv0 != "gh":
            return True
        return _gh_publishes(token, tokens[i + 1:])
    return False


def _gh_publishes(sub: str, rest) -> bool:
    """`gh pr list` reads; `gh pr create` publishes; `gh api` needs a method."""
    rest = [as_text(t) for t in rest]
    if sub == "api":
        for j, token in enumerate(rest):
            if token in ("-X", "--method") and j + 1 < len(rest):
                return rest[j + 1].upper() in GH_API_MUTATING_METHODS
            if token.upper().startswith("--METHOD="):
                return token.split("=", 1)[1].upper() in GH_API_MUTATING_METHODS
        return False                    # GET by default
    verbs = GH_PUBLISH_VERBS.get(sub)
    if verbs is None:
        return True
    for token in rest:
        if token.startswith("-"):
            continue
        return token in verbs
    return False                        # bare `gh pr` prints help


def _advancing_phase_ok(skill: str, phase: int) -> bool:
    target = ADVANCING_SKILLS[skill]
    if target == 5:
        # Step 5 opens once implementation has actually begun — phase 4, which is
        # entered by the first write, not merely by /autoplan finishing. Verifying
        # an implementation that does not exist yet is not a verification step.
        return phase == 4
    return target == phase + 1


def record_write(state: dict) -> dict:
    """First write after /autoplan enters phase 4 (implementation under way).

    Deliberately does NOT stamp phase_prompt_id: a write is implementation
    progress, not a step invocation, so it must not impose a turn boundary
    between writing code and verifying it.
    """
    if state.get("phase") == 3:
        state["phase"] = 4
    return state


def next_step_skills(phase: int):
    """The skills that advance out of this phase — what a deny message names."""
    if phase >= TERMINAL_PHASE:
        return set()
    return {s for s in ADVANCING_SKILLS if _advancing_phase_ok(s, phase)}


def decide(state: dict, tool_name, tool_input, cwd=None):
    """Return (decision, reason, rule). decision is 'allow' or 'deny'."""
    phase = state.get("phase", 0)
    current = state.get("current_prompt_id")

    if state.get("bypass_prompt_id") and state["bypass_prompt_id"] == current:
        return "allow", "bypass active for this request", "bypass"

    if not isinstance(tool_input, dict):
        # A payload shape we do not recognise must not be read as permission.
        tool_input = {}
    if not isinstance(tool_name, str):
        # Claude Code always sends a string. A list or number is a malformed
        # payload, and coercing it produced a name matching no known tool, which
        # fell through to the ungated branch and let an Edit past the write gate.
        return ("deny", "Workflow gate: malformed payload — tool_name is not a "
                "string, so this call cannot be classified.", "payload_malformed")

    if tool_name == "Skill":
        return _decide_skill(state, as_text(tool_input.get("skill")), phase, current)

    if tool_name in WRITE_TOOLS:
        path = tool_input.get("file_path", "")
        if is_docs_path(path, cwd):
            return "allow", "docs path carve-out", "carveout_docs"
        if phase < WRITE_UNLOCK_PHASE:
            return (
                "deny",
                _write_deny_reason(phase),
                "write_before_phase3",
            )
        return "allow", f"phase {phase} permits writes", "write_ok"

    if tool_name == "Bash":
        return _decide_bash(state, tool_input, phase)

    if tool_name in ALWAYS_ALLOWED_TOOLS:
        return "allow", "read-only / always-allowed tool", "always_allowed"

    # Unknown tool: allow. The gate governs the workflow, not the tool registry,
    # and denying every future tool Anthropic ships would be a lockout.
    return "allow", f"tool {tool_name} is not gated", "ungated_tool"


def _decide_skill(state, skill, phase, current):
    if skill in NON_ADVANCING_SKILLS:
        if phase >= NON_ADVANCING_SKILLS[skill]:
            return "allow", f"{skill} is allowed from phase {NON_ADVANCING_SKILLS[skill]}", "skill_augment"
        return (
            "deny",
            f"/{skill} is a phase-{NON_ADVANCING_SKILLS[skill]} augment; you are at phase {phase}.",
            "skill_augment_early",
        )

    target = ADVANCING_SKILLS.get(skill)
    if target is None:
        return "allow", "skill is not part of the workflow", "skill_offworkflow"

    if not _advancing_phase_ok(skill, phase):
        names = ", ".join("/" + s for s in sorted(next_step_skills(phase)))
        return (
            "deny",
            f"Out of order: /{skill} advances to step {target} but you are at phase {phase}. "
            f"Run one of: {names or 'nothing — /ship was the terminal step'}.",
            "skill_out_of_order",
        )

    # Transition wait: a step may not follow another inside the same user turn.
    if state.get("phase_prompt_id") and state["phase_prompt_id"] == current:
        return (
            "deny",
            f"Step transition needs a new turn. Step {phase} completed in this same "
            f"request; present your results, end the turn, and /{skill} will be "
            f"allowed after the user replies.",
            "transition_same_turn",
        )
    return "allow", f"/{skill} advances phase {phase} to {target}", "skill_advance"


def _write_deny_reason(phase: int) -> str:
    names = ", ".join("/" + s for s in sorted(next_step_skills(phase)))
    return (
        f"Workflow gate: code writes unlock at phase {WRITE_UNLOCK_PHASE} "
        f"(after /autoplan). You are at phase {phase}. Next: {names}. "
        f"Docs and *.md are always writable. Note: writes made through Bash are "
        f"NOT detected — Bash itself is phase-gated instead. "
        f"The owner can type `gate: off` to bypass this one request."
    )


def _decide_bash(state, tool_input, phase):
    return "allow", "Bash is not gated (see the note above the constants)", "bash_ok"
