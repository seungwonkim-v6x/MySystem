#!/usr/bin/env bats
# Phase ordering and the write unlock (ADR-0024).
#
# The invariant: writes are impossible before /autoplan, and steps cannot be
# invoked out of order. Five prose attempts (ADR-0016/0019/0020/0021 and a sixth
# abandoned) reached 46-62% compliance. These tests exist so the mechanism that
# replaced the prose cannot regress silently.

load helpers/gate

setup() { gate_setup; }

@test "phase 0 denies a code write" {
  prompt "add a feature"
  run gate Write '{"file_path":"src/a.py"}'
  [ "$output" = "deny write_before_phase3" ]
}

@test "phase 0 emits an actual deny payload, not just a log line" {
  prompt "add a feature"
  gate Write '{"file_path":"src/a.py"}'
  gate_emitted_deny
}

@test "read-only tools are never gated" {
  prompt "look around"
  run gate Read '{"file_path":"src/a.py"}'
  [ "$output" = "allow always_allowed" ]
}

@test "a Step-1 skill is allowed at phase 0" {
  prompt "add a feature"
  run gate Skill '{"skill":"scope-check"}'
  [ "$output" = "allow skill_advance" ]
}

@test "all three Step-1 skills are accepted, none is privileged" {
  prompt "add a feature"
  for s in scope-check office-hours investigate; do
    run gate Skill "{\"skill\":\"$s\"}"
    [ "$output" = "allow skill_advance" ]
  done
}

@test "skipping to /autoplan from phase 0 is denied" {
  prompt "add a feature"
  run gate Skill '{"skill":"autoplan"}'
  [ "$output" = "deny skill_out_of_order" ]
}

@test "skipping Step 2 is denied — the vendor default cannot win here" {
  # The CLI injects "Do not use workflows or deep-research unless the user
  # requested it" as an Opus-5 prompt-bundle default. Prose cannot outrank a
  # provider default (ADR-0021:41-45), so the gate settles it by refusing.
  prompt "add a feature"
  ran scope-check p1
  run gate Skill '{"skill":"autoplan"}' p2
  [ "$output" = "deny skill_out_of_order" ]
}

@test "writes unlock once phase 3 is reached" {
  reach_phase3
  [ "$(phase_now)" = "3" ]
  run gate Write '{"file_path":"src/a.py"}' p4
  [ "$output" = "allow write_ok" ]
}

@test "backtracking to an earlier step is denied" {
  reach_phase3
  run gate Skill '{"skill":"scope-check"}' p4
  [ "$output" = "deny skill_out_of_order" ]
}

@test "Step 6 needs BOTH review passes before /ship unlocks" {
  reach_phase4
  ran verify-test p5
  ran review p6
  run gate Skill '{"skill":"ship"}' p7
  [ "$output" = "deny skill_out_of_order" ]

  ran requesting-code-review p7
  [ "$(phase_now)" = "6" ]
  run gate Skill '{"skill":"ship"}' p8
  [ "$output" = "allow skill_advance" ]
}

@test "the Step-5 augment is allowed once implementation has begun" {
  reach_phase4
  [ "$(phase_now)" = "4" ]
  run gate Skill '{"skill":"verification-before-completion"}' p5
  [ "$output" = "allow skill_augment" ]
}

@test "a Step-5 check is denied until a write has actually happened" {
  reach_phase3
  run gate Skill '{"skill":"verify-test"}' p4
  [ "$output" = "deny skill_out_of_order" ]
}

@test "the first write enters phase 4 without imposing a turn boundary" {
  # Writing code then verifying it in the same turn must stay possible; the
  # wait belongs between STEPS, not between an edit and its verification.
  reach_phase4
  run gate Skill '{"skill":"verify-test"}' p4
  [ "$output" = "allow skill_advance" ]
}

@test "the Step-5 augment is denied before implementation" {
  prompt "add a feature"
  run gate Skill '{"skill":"verification-before-completion"}'
  [ "$output" = "deny skill_augment_early" ]
}

@test "an off-workflow skill is not gated" {
  prompt "add a feature"
  run gate Skill '{"skill":"humanizer"}'
  [ "$output" = "allow skill_offworkflow" ]
}

@test "an unknown tool is allowed rather than locked out" {
  # Denying every tool Anthropic ships next would be a lockout, not a gate.
  prompt "add a feature"
  run gate SomeFutureTool '{"x":1}'
  [ "$output" = "allow ungated_tool" ]
}
