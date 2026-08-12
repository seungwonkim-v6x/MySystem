#!/usr/bin/env bats
# Malformed input must never open the gate (ADR-0024).
#
# Regression tests for three bugs found by throwaway verification, not by the
# contract tests above. Root cause was shared: the gate fails OPEN on a crash so
# that a bug cannot brick a session, which means ANY TypeError raised while
# reading a malformed marker or an odd tool_input silently DISABLED enforcement.
# That is the worst failure this design can have — corruption reading as
# permission — so the sanitising in lib.load()/as_text() is load-bearing and
# these tests exist to keep it.
#
# Found: a marker holding `[1,2,3]`, a `phase` of `"3"`, and a numeric
# `file_path` each produced allow where deny was required.

load helpers/gate

setup() { gate_setup; prompt "add a feature" p1; }

write_marker() { # $1 = raw file contents
  mkdir -p "$MYSYSTEM_STATE_HOME/steps"
  printf '%s' "$1" > "$MYSYSTEM_STATE_HOME/steps/$SESSION.json"
}

@test "a marker that is valid JSON but not an object stays closed" {
  write_marker '[1,2,3]'
  run gate Write '{"file_path":"src/a.py"}'
  [ "$output" = "deny write_before_phase3" ]
}

@test "a marker whose phase is a string stays closed" {
  write_marker '{"phase":"3"}'
  run gate Write '{"file_path":"src/a.py"}'
  [ "$output" = "deny write_before_phase3" ]
}

@test "a truncated marker stays closed" {
  write_marker '{"phase": 3, "steps": ['
  run gate Write '{"file_path":"src/a.py"}'
  [ "$output" = "deny write_before_phase3" ]
}

@test "a negative phase stays closed" {
  write_marker '{"phase":-5}'
  run gate Write '{"file_path":"src/a.py"}'
  [ "$output" = "deny write_before_phase3" ]
}

@test "a phase above the terminal one is clamped, not trusted blindly" {
  # Clamping is hygiene, not security: anyone who can write the marker can also
  # edit settings.json, so a forged marker is trusted by construction. What must
  # not happen is an out-of-range value reaching arithmetic that then crashes
  # into the fail-open path.
  write_marker '{"phase":99}'
  run gate Skill '{"skill":"scope-check"}'
  [ "$output" = "deny skill_out_of_order" ]
}

@test "a marker with a non-list steps field stays usable" {
  write_marker '{"phase":0,"steps":"oops"}'
  run gate Write '{"file_path":"src/a.py"}'
  [ "$output" = "deny write_before_phase3" ]
}

@test "a numeric file_path does not open the gate" {
  run gate Write '{"file_path":42}'
  [ "$output" = "deny write_before_phase3" ]
}

@test "a non-object tool_input does not open the gate" {
  for ti in '[]' '"hello"' 'null' '42'; do
    run gate Write "$ti"
    [ "$output" = "deny write_before_phase3" ]
  done
}

@test "an unwritable gate log does not block the decision" {
  mkdir -p "$MYSYSTEM_STATE_HOME/gate-log.jsonl"
  printf '{"session_id":"%s","prompt_id":"p1","tool_name":"Write","tool_input":{"file_path":"src/a.py"}}' \
    "$SESSION" | python3 "$HOOKS/gate.py" > "$BATS_TEST_TMPDIR/out.json"
  [ "$?" -eq 0 ]
  grep -q '"permissionDecision": "deny"' "$BATS_TEST_TMPDIR/out.json"
}

@test "a crash inside the gate fails OPEN so a bug cannot brick a session" {
  # The accepted residual risk, pinned so it stays deliberate. A broken library
  # beside a copy of the hook is the only way to induce a real crash: gate.py
  # puts its own directory first on sys.path, so PYTHONPATH cannot shadow it.
  tmp="$BATS_TEST_TMPDIR/broken"
  mkdir -p "$tmp"
  cp "$HOOKS/gate.py" "$tmp/"
  cat > "$tmp/mysystem_steps_lib.py" <<'EOF'
def now(): return "x"
WRITE_TOOLS = set()
def load(s): raise RuntimeError("induced crash")
EOF
  run bash -c "printf '%s' '{\"session_id\":\"s\",\"prompt_id\":\"p\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"a.py\"}}' | MYSYSTEM_STATE_HOME='$MYSYSTEM_STATE_HOME' python3 '$tmp/gate.py'"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "malformed stdin fails open rather than blocking every tool" {
  run bash -c "printf 'not json' | python3 '$HOOKS/gate.py'"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "two sessions do not see each other's phase or bypass" {
  OTHER="sess-other"
  SESSION="$OTHER" prompt "build" p1
  reach_phase3

  run gate Write '{"file_path":"src/a.py"}' p4
  [ "$output" = "allow write_ok" ]

  SESSION="$OTHER" run gate Write '{"file_path":"src/a.py"}' p4
  [ "$output" = "deny write_before_phase3" ]
}

# Concurrency. The model can emit several tool calls in one message, so two
# PostToolUse hooks run at once and `load(); mutate; save()` loses an update.
# The library used to claim "single writer per session, so no locking" and that
# was wrong: reproduced with the two Step-6 review passes, which CLAUDE.md says to
# launch concurrently — one steps entry vanished, phase stayed 5, /ship never
# unlocked. lib.locked() serialises the read-modify-write.
@test "concurrent Step-6 review passes both survive" {
  reach_phase4
  ran verify-test p5

  printf '{"hook_event_name":"PostToolUse","session_id":"%s","prompt_id":"p6","tool_name":"Skill","tool_input":{"skill":"review"}}' \
    "$SESSION" | python3 "$HOOKS/record-step.py" &
  printf '{"hook_event_name":"PostToolUse","session_id":"%s","prompt_id":"p6","tool_name":"Skill","tool_input":{"skill":"requesting-code-review"}}' \
    "$SESSION" | python3 "$HOOKS/record-step.py" &
  wait

  [ "$(phase_now)" = "6" ]
}

@test "concurrent recordings of distinct steps all survive" {
  # Distinct prompt_ids on purpose: handle_skill deliberately collapses the same
  # skill under the same prompt_id, because the typed path records it too.
  reach_phase3
  for i in 1 2 3 4 5 6; do
    printf '{"hook_event_name":"PostToolUse","session_id":"%s","prompt_id":"pw%s","tool_name":"Skill","tool_input":{"skill":"aside-qa"}}' \
      "$SESSION" "$i" | python3 "$HOOKS/record-step.py" &
  done
  wait
  run python3 - "$MYSYSTEM_STATE_HOME/steps/$SESSION.json" <<'PY'
import json, sys
steps = json.load(open(sys.argv[1], encoding="utf-8"))["steps"]
print(sum(1 for s in steps if s.get("skill") == "aside-qa"))
PY
  [ "$output" = "6" ]
}

@test "a stale lock left by a killed process is reclaimed" {
  prompt "build" p1
  mkdir -p "$MYSYSTEM_STATE_HOME/steps"
  lock="$MYSYSTEM_STATE_HOME/steps/$SESSION.json.lock"
  mkdir "$lock"
  touch -t 202001010000 "$lock"
  ran scope-check p1
  [ "$(phase_now)" = "1" ]
}

# --- Findings closed by the Step-6 fresh-context review ---------------------

@test "a docs/.. traversal cannot launder a source path" {
  # `/repo/docs/../hooks/gate.py` passed as a docs write at phase 0, which made
  # every file in the repo — the gate itself included — writable before Step 1.
  prompt "build" p1
  for p in "/repo/docs/../hooks/gate.py" "docs/../src/main.py" "a/docs/../../src/x.py"; do
    run gate Write "{\"file_path\":\"$p\"}"
    [ "$output" = "deny write_before_phase3" ]
  done
  run gate Write '{"file_path":"docs/adr/0024-x.md"}'
  [ "$output" = "allow carveout_docs" ]
}

@test "tests/fixtures is no longer a write carve-out" {
  # It can hold executable code, and with Bash ungated that is a write-then-run pair.
  prompt "build" p1
  run gate Write '{"file_path":"tests/fixtures/x.py"}'
  [ "$output" = "deny write_before_phase3" ]
}

@test "a non-dict tool_input is denied, and the hook still logs" {
  # This was a Critical fail-open: the deny was computed, then log_decision
  # crashed on the non-dict, and the crash handler turned it into an allow. The
  # suite reported green because the helper read the PREVIOUS call's log line.
  prompt "build" p1
  for ti in '"hello"' '42' '[]' 'null' '[{"x":1}]'; do
    run gate Write "$ti"
    [ "$output" = "deny write_before_phase3" ]
  done
}

@test "a typed skill cannot jump the phase" {
  # A user-typed /skill arrives via UserPromptSubmit and never passes PreToolUse,
  # so record_skill has to apply the ordering rule itself. A session whose first
  # prompt was `/autoplan` reached phase 3 and unlocked writes with steps 1 and 2
  # never run.
  prompt "/autoplan build the thing" p1
  [ "$(phase_now)" = "0" ]
  run gate Write '{"file_path":"src/main.py"}' p2
  [ "$output" = "deny write_before_phase3" ]
}

@test "a typed skill in the right order still advances" {
  prompt "/scope-check do the thing" p1
  [ "$(phase_now)" = "1" ]
}

@test "a Skill payload with no prompt_id cannot defeat the turn boundary" {
  prompt "build" p1
  printf '{"hook_event_name":"PostToolUse","session_id":"%s","tool_name":"Skill","tool_input":{"skill":"scope-check"}}' \
    "$SESSION" | python3 "$HOOKS/record-step.py"
  run gate Skill '{"skill":"deep-research"}' p1
  [ "$output" = "deny transition_same_turn" ]
}

@test "merely mentioning the bypass does not arm it" {
  # "remind me what gate: off actually does" armed the bypass and `rm -rf src`
  # was then allowed. A bypass must be a command, not a phrase.
  for text in "before we start, remind me what gate: off actually does" \
              "the docs say gate: off works per request" \
              "do not use /gate-off here"; do
    prompt "$text" p2
    run gate Write '{"file_path":"src/a.py"}' p2
    [ "$output" = "deny write_before_phase3" ]
  done
}

@test "the bypass still works when it leads the prompt" {
  prompt "gate: off — just do it" p2
  run gate Write '{"file_path":"src/a.py"}' p2
  [ "$output" = "allow bypass" ]
}

@test "merely mentioning a reset does not zero the workflow" {
  reach_phase3
  prompt "what would gate: reset do to my phase?" p9
  [ "$(phase_now)" = "3" ]
}

@test "the helper reports a crash instead of a stale verdict" {
  # Pins the fix for the flaw that let a Critical fail-open ship as covered.
  tmp="$BATS_TEST_TMPDIR/broken2"
  mkdir -p "$tmp"
  cp "$HOOKS/gate.py" "$tmp/"
  printf 'def now(): return "x"\nWRITE_TOOLS = set()\ndef load(s): raise RuntimeError("boom")\n' \
    > "$tmp/mysystem_steps_lib.py"
  prompt "build" p1
  gate Write '{"file_path":"src/a.py"}'   # one real call, so a log line exists

  local log="$MYSYSTEM_STATE_HOME/gate-log.jsonl"
  local before; before=$(wc -l < "$log" | tr -d ' ')
  printf '{"session_id":"s","prompt_id":"p","tool_name":"Write","tool_input":{"file_path":"a.py"}}' \
    | python3 "$tmp/gate.py" > /dev/null
  local after; after=$(wc -l < "$log" | tr -d ' ')
  [ "$after" -eq "$before" ]
}

@test "a symlink cannot launder a source path through the docs carve-out" {
  # normpath let `docs/notes.md -> hooks/gate.py` overwrite the gate. realpath closes it.
  ln -sf "$REPO_ROOT/hooks/gate.py" "$REPO_ROOT/docs/.gate-symlink-probe.md"
  run gate Write '{"file_path":"docs/.gate-symlink-probe.md"}'
  rm -f "$REPO_ROOT/docs/.gate-symlink-probe.md"
  [ "$output" = "deny write_before_phase3" ]
}

@test "a malformed tool_name is denied, not waved through" {
  # decide() returned deny, then `tool_name in WRITE_TOOLS` on a list raised
  # TypeError while building the LOG entry and the crash handler emitted an allow.
  for tn in '["Edit"]' '7' '{"a":1}' 'null'; do
    local log="$MYSYSTEM_STATE_HOME/gate-log.jsonl"
    printf '{"cwd":"%s","session_id":"%s","prompt_id":"p1","tool_name":%s,"tool_input":{"file_path":"src/a.py"}}' \
      "$REPO_ROOT" "$SESSION" "$tn" | python3 "$HOOKS/gate.py" > "$BATS_TEST_TMPDIR/o.json"
    grep -q '"permissionDecision": "deny"' "$BATS_TEST_TMPDIR/o.json"
  done
}

@test "an out-of-order typed skill is not recorded at all" {
  # Appending before the ordering check let a typed /review from any earlier turn
  # satisfy the Step-6 conjunction, unlocking publishing with one review pass.
  prompt "/review" p0
  run python3 "$BATS_TEST_DIRNAME/helpers/steps.py" "$MYSYSTEM_STATE_HOME/steps/$SESSION.json"
  [ "$output" = "" ]
}
