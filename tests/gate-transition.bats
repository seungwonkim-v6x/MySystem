#!/usr/bin/env bats
# The step transition wait, enforced (ADR-0024).
#
# This is fb35992's "After presenting results, STOP and wait" expressed as a
# check that returns pass/fail. ADR-0019 deleted that prose, ADR-0020 declined to
# restore it, ADR-0021 restored only the mandatory-invocation rule. Compliance
# tracked the prose (0-8% absent, 46-62% present) and never went higher, so the
# wait is a comparison of prompt_ids here rather than a sentence.

load helpers/gate

setup() { gate_setup; }

@test "two steps in one turn: the second is denied" {
  prompt "build a thing" p1
  ran scope-check p1
  run gate Skill '{"skill":"deep-research"}' p1
  [ "$output" = "deny transition_same_turn" ]
}

@test "the same step succeeds once the owner has replied" {
  prompt "build a thing" p1
  ran scope-check p1
  run gate Skill '{"skill":"deep-research"}' p2
  [ "$output" = "allow skill_advance" ]
}

@test "the wait applies at every transition, not only the first" {
  prompt "build a thing" p1
  ran scope-check p1
  ran deep-research p2
  run gate Skill '{"skill":"autoplan"}' p2
  [ "$output" = "deny transition_same_turn" ]
  run gate Skill '{"skill":"autoplan"}' p3
  [ "$output" = "allow skill_advance" ]
}

@test "the first step of a session needs no prior turn" {
  # There is no previous step to wait after, so phase 0 to 1 must not be gated
  # by the transition rule or nothing could ever start.
  prompt "build a thing" p1
  run gate Skill '{"skill":"scope-check"}' p1
  [ "$output" = "allow skill_advance" ]
}

@test "writing code does not impose a wait before verifying it" {
  reach_phase4
  run gate Skill '{"skill":"verify-test"}' p4
  [ "$output" = "allow skill_advance" ]
}

@test "a write in the same turn as /autoplan is still allowed" {
  # The wait governs STEP transitions. Implementation is step 4's content, not a
  # separate step, so /autoplan then Write inside one turn must work.
  reach_phase3
  run gate Write '{"file_path":"src/a.py"}' p3
  [ "$output" = "allow write_ok" ]
}
