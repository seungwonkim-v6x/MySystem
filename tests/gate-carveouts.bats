#!/usr/bin/env bats
# Carve-outs and the escape hatch (ADR-0024).
#
# Every carve-out here is a mechanical predicate over the tool input. None asks
# the model whether something is trivial: that would hand back the discretion the
# gate exists to remove. ADR-0023 named the ABSENCE of these carve-outs as a
# decisive objection to the previous attempt, since enforce mode would have
# blocked the typo fixes CLAUDE.md explicitly permits.

load helpers/gate

setup() { gate_setup; prompt "add a feature" p1; }

@test "the repo's own docs are writable at phase 0" {
  # Named files and the docs/ tree only. A blanket `*.md` used to make
  # ~/.claude/skills/**/SKILL.md writable, and those are instructions the agent
  # executes, not documentation.
  for p in docs/adr/0024-x.md CHANGELOG.md VERSION TODOS.md CONTEXT.md .gitignore; do
    run gate Write "{\"file_path\":\"$p\"}"
    [ "$output" = "allow carveout_docs" ]
  done
}

@test "a markdown file outside the docs set is not writable at phase 0" {
  for p in README.md src/notes.md /tmp/x.md; do
    run gate Write "{\"file_path\":\"$p\"}"
    [ "$output" = "deny write_before_phase3" ]
  done
}

@test "a docs path outside the invoking repo is not writable" {
  run gate Write '{"file_path":"/repo/docs/adr/0024-thing.md"}'
  [ "$output" = "deny write_before_phase3" ]
}

@test "source files are not smuggled through the docs carve-out" {
  run gate Write '{"file_path":"src/markdown.py"}'
  [ "$output" = "deny write_before_phase3" ]
}

@test "gate: off — the canonical form — unblocks that request" {
  # Canonical because it is the only form that survives the CLI. A leading slash
  # is resolved as a command and an unknown one is rejected with "Unknown
  # command" before the prompt is submitted, so /gate-off never reaches the hook.
  # Found end-to-end; the unit tier cannot see it because it feeds the hook directly.
  prompt "gate: off — I know what I am doing" p2
  run gate Write '{"file_path":"src/a.py"}' p2
  [ "$output" = "allow bypass" ]
}

@test "the /gate-off alias still parses, for hosts that register it" {
  prompt "/gate-off just do it" p2
  run gate Write '{"file_path":"src/a.py"}' p2
  [ "$output" = "allow bypass" ]
}

@test "the bypass expires with the next request" {
  prompt "gate: off" p2
  run gate Write '{"file_path":"src/a.py"}' p2
  [ "$output" = "allow bypass" ]

  prompt "now do the next thing" p3
  run gate Write '{"file_path":"src/a.py"}' p3
  [ "$output" = "deny write_before_phase3" ]
}

@test "the bypass covers a Bash call for that one request too" {
  prompt "gate: off" p2
  run gate Bash '{"command":"make"}' p2
  [ "$output" = "allow bypass" ]
}

@test "a bypass the AGENT emits cannot arm the gate" {
  # Only UserPromptSubmit can arm the bypass, so text the model produces must not.
  # The earlier version of this test ran a payload containing no bypass text at
  # all, so it would have passed against an implementation that armed the bypass
  # from any Skill payload — it did not test its own name. Now the bypass phrase
  # is actually present in the agent-side payloads.
  printf '{"hook_event_name":"PostToolUse","session_id":"%s","prompt_id":"p1","tool_name":"Skill","tool_input":{"skill":"scope-check","args":"gate: off"}}' \
    "$SESSION" | python3 "$HOOKS/record-step.py"
  run gate Write '{"file_path":"src/a.py"}' p1
  [ "$output" = "deny write_before_phase3" ]

  # And a PostToolUse write payload whose path contains the phrase.
  printf '{"hook_event_name":"PostToolUse","session_id":"%s","prompt_id":"p1","tool_name":"Write","tool_input":{"file_path":"gate: off.md"}}' \
    "$SESSION" | python3 "$HOOKS/record-step.py"
  run gate Write '{"file_path":"src/a.py"}' p1
  [ "$output" = "deny write_before_phase3" ]
}

@test "the trivial-edit carve-out is gone: a typo needs Step 1 or a bypass" {
  # It admitted `PUBLISH_UNLOCK_PHASE = 6` -> `= 0` at phase 0 — the gate turning
  # off its own threshold — because a 0.6 similarity ratio over one 40-char line
  # permits arbitrary logic flips, and carve-outs were evaluated BEFORE the phase
  # check. `gate: off` covers a real typo without a predicate to defeat.
  run gate Edit '{"file_path":"src/a.py","old_string":"recieve","new_string":"receive"}'
  [ "$output" = "deny write_before_phase3" ]
  run gate Edit '{"file_path":"src/a.py","old_string":"if user.is_admin:","new_string":"if not user.is_admin:"}'
  [ "$output" = "deny write_before_phase3" ]
}
