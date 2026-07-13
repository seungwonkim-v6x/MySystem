#!/usr/bin/env bats
# Smoke test for repo utility scripts.

SCRIPTS="$BATS_TEST_DIRNAME/../scripts"

@test "claude-md-budget.sh reports separate Codex global and project budgets" {
  # Pin CLAUDE_HOME to the repo so local runs and CI exercise the same tree
  # (default would scan the live ~/.claude including untracked state).
  CLAUDE_HOME="$BATS_TEST_DIRNAME/.." run bash "$SCRIPTS/claude-md-budget.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLAUDE.md"* ]]
  [[ "$output" == *"Codex global projection"* ]]
  [[ "$output" == *"Codex project supplement"* ]]
}

@test "generated projections are current" {
  run "$SCRIPTS/render-codex-agents.sh" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROJECTIONS_CURRENT"* ]]
}

@test "operational docs do not claim one shared Codex instruction cap" {
  run grep -R -E "Codex cap target \(CLAUDE.md alone\)|Codex CLI will truncate.*CLAUDE.md" \
    "$BATS_TEST_DIRNAME/../README.md" \
    "$BATS_TEST_DIRNAME/../SETUP.md" \
    "$BATS_TEST_DIRNAME/../CONTEXT.md" \
    "$BATS_TEST_DIRNAME/../scripts"
  [ "$status" -eq 1 ]
}

@test "setup command family documents public parity operations" {
  run "$BATS_TEST_DIRNAME/../setup.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--parity-only"* ]]
  [[ "$output" == *"doctor"* ]]
  [[ "$output" == *"--recover"* ]]
}

@test "setup command family rejects unknown operations with exit 2" {
  run "$BATS_TEST_DIRNAME/../setup.sh" --unknown-operation
  [ "$status" -eq 2 ]
}
