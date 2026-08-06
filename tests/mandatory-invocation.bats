#!/usr/bin/env bats
#
# Watchdog for the ADR-0021 mandatory-invocation restore.
#
# CLAUDE.md's `## Critical Workflow Rules` holds three paragraphs that are
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

# Locate the single contract line containing $1, then assert CLAUDE.md carries
# that whole line verbatim. Both halves fail loudly and say which one broke.
assert_surfaces_agree() {
  local anchor=$1 line hits
  hits=$(grep -cF -- "$anchor" "$CONTRACT" 2>/dev/null || true)
  if [ "${hits:-0}" -ne 1 ]; then
    printf 'Anchor is no longer unique in %s (found %s lines):\n  %s\nThe anchor itself needs updating before this test can guard anything.\n' \
      "$CONTRACT" "${hits:-0}" "$anchor" >&2
    return 1
  fi
  line=$(grep -F -- "$anchor" "$CONTRACT")
  if ! grep -Fqx -- "$line" "$CLAUDE_MD"; then
    printf 'The two instruction surfaces have drifted (ADR-0021).\ncodex/workflow-contract.md carries:\n  %s\nCLAUDE.md does not carry that line verbatim.\nChanging the workflow means changing both surfaces — or amending ADR-0021.\n' \
      "$line" >&2
    return 1
  fi
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

# The gates are the one thing ADR-0021 deliberately did NOT copy across. If this
# paragraph ever lands in CLAUDE.md, the surface split collapsed back into the
# gated contract that ADR-0019 measured and rejected.
@test "CLAUDE.md does NOT carry the Codex-only approval-gate paragraph" {
  run grep -Fq 'NEVER proceed to the next workflow step without explicit user approval' "$CLAUDE_MD"
  [ "$status" -ne 0 ]
}
