#!/usr/bin/env bats
# Smoke test for repo utility scripts.

SCRIPTS="$BATS_TEST_DIRNAME/../scripts"

@test "claude-md-budget.sh runs clean and reports the Codex cap comparison" {
  # Pin CLAUDE_HOME to the repo so local runs and CI exercise the same tree
  # (default would scan the live ~/.claude including untracked state).
  CLAUDE_HOME="$BATS_TEST_DIRNAME/.." run bash "$SCRIPTS/claude-md-budget.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLAUDE.md"* ]]
}
