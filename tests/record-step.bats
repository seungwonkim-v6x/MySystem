#!/usr/bin/env bats
# The recorder (ADR-0024).
#
# It must never deny, and it must see BOTH paths a skill can arrive by. A
# user-typed `/scope-check` fires no Skill hook at all (measured on CLI 2.1.227,
# contradicting the vendor docs), so a recorder listening only to Skill would
# leave the gate denying an owner who did run the step. That is the regression
# these tests exist to prevent.

load helpers/gate

setup() { gate_setup; }

@test "an agent-invoked skill advances the phase" {
  prompt "build a thing" p1
  ran scope-check p1
  [ "$(phase_now)" = "1" ]
}

@test "a user-TYPED skill advances the phase" {
  prompt "/scope-check" p1
  [ "$(phase_now)" = "1" ]
}

@test "a typed skill with arguments still counts" {
  prompt "/scope-check restore the approval waits" p1
  [ "$(phase_now)" = "1" ]
}

@test "a typed skill then the same skill invoked is not double-recorded" {
  prompt "/scope-check" p1
  ran scope-check p1
  run python3 - "$MYSYSTEM_STATE_HOME/steps/$SESSION.json" <<'PY'
import json, sys
print(len(json.load(open(sys.argv[1], encoding="utf-8"))["steps"]))
PY
  [ "$output" = "1" ]
}

@test "an off-workflow typed command does not advance anything" {
  prompt "/humanizer" p1
  [ "$(phase_now)" = "0" ]
}

@test "ordinary prose does not advance anything" {
  prompt "please add a feature to the parser" p1
  [ "$(phase_now)" = "0" ]
}

@test "the recorder never denies" {
  run bash -c "printf '%s' '{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"x\",\"prompt_id\":\"p\",\"prompt\":\"hi\"}' | python3 '$HOOKS/record-step.py'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a malformed payload fails open rather than blocking" {
  run bash -c "printf 'not json' | python3 '$HOOKS/record-step.py'"
  [ "$status" -eq 0 ]
}

@test "a new request after /ship starts a fresh cycle" {
  reach_phase4
  ran verify-test p5
  ran review p6
  ran requesting-code-review p7
  ran ship p8
  [ "$(phase_now)" = "7" ]

  prompt "now a different task" p9
  [ "$(phase_now)" = "0" ]
}

@test "/gate-reset starts a fresh cycle on demand" {
  reach_phase3
  [ "$(phase_now)" = "3" ]
  prompt "/gate-reset new scope now" p9
  [ "$(phase_now)" = "0" ]
}

@test "a mid-workflow request does NOT reset the phase" {
  # Documented limit: only /ship or an explicit /gate-reset starts a new cycle.
  # Resetting on every prompt would demand re-running Step 1 for every follow-up
  # message, which is unusable; not resetting means a follow-up inherits the
  # unlocked phase. The owner has /gate-reset for the case that matters.
  reach_phase3
  prompt "also tweak the error message" p9
  [ "$(phase_now)" = "3" ]
}

@test "the first write advances phase 3 to 4" {
  reach_phase3
  wrote src/a.py p4
  [ "$(phase_now)" = "4" ]
}

@test "a write before phase 3 does not advance anything" {
  prompt "build a thing" p1
  wrote src/a.py p1
  [ "$(phase_now)" = "0" ]
}
