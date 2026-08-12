#!/usr/bin/env bash
# Shared helper for the workflow-gate tests (ADR-0024).
#
# Tests assert on the gate's `rule` name rather than the deny prose, so wording
# stays free to improve while policy does not drift — the same reasoning as
# step1-routing.bats.
#
# STDOUT IS THE SOURCE OF TRUTH. The first version of this helper read only the
# LAST line of gate-log.jsonl. A gate that crashes writes no line, so the helper
# silently reported the PREVIOUS call's verdict and the test passed. That masked a
# Critical fail-open — a non-dict `tool_input` turned a deny into an allow — and
# every multi-assertion loop in the suite shared the flaw. Found by fresh-context
# review, not by the suite itself. Now: a missing log line is a failure, and a log
# line that disagrees with what the hook actually printed is a failure, because
# stdout is what Claude Code acts on.

gate_setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export MYSYSTEM_STATE_HOME="$BATS_TEST_TMPDIR/state"
  HOOKS="$BATS_TEST_DIRNAME/../hooks"
  SESSION="sess-test"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

# gate <tool_name> <tool_input_json> [prompt_id]
# Prints "<decision> <rule>" — or a loud marker when the two disagree.
gate() {
  local tool="$1" input="$2" pid="${3:-p1}"
  local log="$MYSYSTEM_STATE_HOME/gate-log.jsonl"
  local before=0
  [ -f "$log" ] && before=$(wc -l < "$log" | tr -d ' ')

  printf '{"cwd":"%s","session_id":"%s","prompt_id":"%s","tool_name":"%s","tool_input":%s}' \
    "$REPO_ROOT" "$SESSION" "$pid" "$tool" "$input" \
    | python3 "$HOOKS/gate.py" > "$BATS_TEST_TMPDIR/last-out.json"

  local after=0
  [ -f "$log" ] && after=$(wc -l < "$log" | tr -d ' ')
  if [ "$after" -le "$before" ]; then
    echo "GATE_WROTE_NO_LOG_LINE"
    return 0
  fi

  python3 "$BATS_TEST_DIRNAME/helpers/gate_verdict.py" \
    "$BATS_TEST_TMPDIR/last-out.json" "$log"
}

# Did the last gate call emit an actual deny payload (not just log one)?
gate_emitted_deny() {
  grep -q '"permissionDecision": "deny"' "$BATS_TEST_TMPDIR/last-out.json"
}

# prompt <text> [prompt_id] — simulate the owner typing something.
prompt() {
  local text="$1" pid="${2:-p1}"
  python3 "$BATS_TEST_DIRNAME/helpers/mkpayload.py" prompt "$SESSION" "$pid" "$text" \
    > "$BATS_TEST_TMPDIR/ups.json"
  python3 "$HOOKS/record-step.py" < "$BATS_TEST_TMPDIR/ups.json"
}

# ran <skill> [prompt_id] — simulate the agent invoking a skill.
ran() {
  local skill="$1" pid="${2:-p1}"
  printf '{"hook_event_name":"PostToolUse","session_id":"%s","prompt_id":"%s","tool_name":"Skill","tool_input":{"skill":"%s"}}' \
    "$SESSION" "$pid" "$skill" | python3 "$HOOKS/record-step.py"
}

# wrote <path> [prompt_id] — simulate a completed write (PostToolUse).
wrote() {
  local path="$1" pid="${2:-p1}"
  printf '{"hook_event_name":"PostToolUse","session_id":"%s","prompt_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' \
    "$SESSION" "$pid" "$path" | python3 "$HOOKS/record-step.py"
}

phase_now() {
  python3 "$BATS_TEST_DIRNAME/helpers/phase.py" "$MYSYSTEM_STATE_HOME/steps/$SESSION.json"
}

# Walk the workflow to phase 3 (writes unlocked), one step per turn.
reach_phase3() {
  prompt "build a thing" p1
  ran scope-check p1
  ran deep-research p2
  ran autoplan p3
}

# Phase 4: implementation actually under way.
reach_phase4() {
  reach_phase3
  wrote src/a.py p4
}
