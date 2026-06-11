#!/usr/bin/env bats
# Smoke test for repo utility scripts.

SCRIPTS="$BATS_TEST_DIRNAME/../scripts"

@test "claude-md-budget.sh runs clean and reports the Codex cap comparison" {
  run bash "$SCRIPTS/claude-md-budget.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLAUDE.md"* ]]
}
