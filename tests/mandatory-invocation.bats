#!/usr/bin/env bats
#
# Watchdog for the mandatory-invocation copies shared by both surfaces
# (ADR-0021, still current) — NOT for the gates, which ADR-0024 moved into
# hooks/gate.py on the Claude Code surface. See tests/gate-*.bats for those.
#
# CLAUDE.md's `## Critical Workflow Rules` holds paragraphs that are
# byte-identical copies of codex/workflow-contract.md. The copying is what makes
# the two instruction surfaces agree on which steps are mandatory — ADR-0021's
# central claim. Nothing else stops an edit to one file from leaving the other
# behind, silently, which is the same failure shape named-override.bats was
# written for in v0.55.0.
#
# These tests fail when the copies diverge in EITHER direction: reword the
# contract and CLAUDE.md goes stale; reword CLAUDE.md and the contract does.
#
# Anchored on a distinctive phrase rather than a line number on purpose. The
# contract's numbering shifts whenever anything above these paragraphs changes,
# and a hardcoded `sed -n '16p'` would then compare CLAUDE.md against the wrong
# line and pass for the wrong reason — a watchdog that reports green while the
# thing it guards is broken is worse than no watchdog.

SOURCE_REPO="$BATS_TEST_DIRNAME/.."
CONTRACT="$SOURCE_REPO/codex/workflow-contract.md"
CLAUDE_MD="$SOURCE_REPO/CLAUDE.md"
RULES_HEADING='## Critical Workflow Rules'

# Print the body of a top-level CLAUDE.md section, stopping at the next `## `.
section_body() {
  awk -v heading="$1" '
    $0 == heading { inside = 1; next }
    inside && /^## / { exit }
    inside { print }
  ' "$CLAUDE_MD"
}

# Locate the single contract line containing $1, then assert CLAUDE.md carries
# that whole line verbatim, EXACTLY ONCE, and INSIDE the operative section.
#
# Existence alone is not enough. A bare `grep -Fqx` passes as long as the line
# survives anywhere in the file, so a stale duplicate left in an appendix would
# keep the suite green while the operative paragraph in Critical Workflow Rules
# quietly drifted — the watchdog reporting green over a broken invariant, which
# is the one outcome this file exists to prevent. Hence three assertions, each
# with its own failure message so a red test says which property broke.
assert_surfaces_agree() {
  local anchor=$1 line n_contract n_file n_section
  n_contract=$(grep -cF -- "$anchor" "$CONTRACT" 2>/dev/null || true)
  if [ "${n_contract:-0}" -ne 1 ]; then
    printf 'Anchor is no longer unique in %s (matched %s lines):\n  %s\nThe anchor itself needs updating before this test can guard anything.\n' \
      "$CONTRACT" "${n_contract:-0}" "$anchor" >&2
    return 1
  fi
  line=$(grep -F -- "$anchor" "$CONTRACT")

  n_file=$(grep -cFx -- "$line" "$CLAUDE_MD" 2>/dev/null || true)
  if [ "${n_file:-0}" -eq 0 ]; then
    printf 'The two instruction surfaces have drifted (ADR-0021, ADR-0024).\ncodex/workflow-contract.md carries:\n  %s\nCLAUDE.md does not carry that line verbatim.\nChanging the workflow means changing both surfaces — or amending the ADR.\n' \
      "$line" >&2
    return 1
  fi
  if [ "${n_file:-0}" -ne 1 ]; then
    printf 'CLAUDE.md carries this contract line %s times; expected exactly 1:\n  %s\nA duplicate can mask later drift in the operative copy. Remove the stale one.\n' \
      "${n_file}" "$line" >&2
    return 1
  fi

  n_section=$(section_body "$RULES_HEADING" | grep -cFx -- "$line" 2>/dev/null || true)
  if [ "${n_section:-0}" -ne 1 ]; then
    printf 'CLAUDE.md carries this contract line, but not inside `%s`:\n  %s\nThe rule is only operative where the agent reads it as a rule.\n' \
      "$RULES_HEADING" "$line" >&2
    return 1
  fi
}

@test "the operative section CLAUDE.md is asserted against actually exists" {
  run grep -Fqx -- "$RULES_HEADING" "$CLAUDE_MD"
  [ "$status" -eq 0 ]
}

@test "both surfaces carry the ZERO-discretion paragraph verbatim" {
  assert_surfaces_agree 'ZERO discretion to skip or reorder workflow steps'
}

@test "both surfaces carry the skill whitelist paragraph verbatim" {
  assert_surfaces_agree 'YOU MUST INVOKE IT BEFORE RESPONDING'
}

@test "both surfaces carry the triviality carve-out verbatim" {
  assert_surfaces_agree 'Triviality carve-out (conservative)'
}

# The gate PROSE is Codex-only and stays that way. ADR-0024 gated the Claude Code
# surface too, but in code (hooks/gate.py) rather than by copying this paragraph,
# because prose is the lever that measured 46-62% and stopped. If the paragraph
# ever lands in CLAUDE.md, someone reverted to the mechanism that did not work.
@test "CLAUDE.md does NOT carry the Codex-only approval-gate paragraph" {
  run grep -Fq 'NEVER proceed to the next workflow step without explicit user approval' "$CLAUDE_MD"
  [ "$status" -ne 0 ]
}
