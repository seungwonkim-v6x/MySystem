#!/usr/bin/env bats
# Behavioral tests for the v0.35.0 defense-in-depth PreToolUse hooks.
# Contract under test: JSON payload on stdin; exit 0 = allow / dry-run,
# exit 2 = block (only when MYSYSTEM_HOOKS_ENFORCE=1); fail-open on error.

HOOKS="$BATS_TEST_DIRNAME/../hooks"

run_bash_hook() { # $1=hook file, $2=command string, rest=env pairs
  local hook="$1" cmd="$2"; shift 2
  printf '{"tool_input":{"command":"%s"}}' "$cmd" |
    env "$@" "$HOOKS/$hook"
}

@test "block-dangerous-git: hard-refuses force-push to main even with bypass env set" {
  run run_bash_hook block-dangerous-git.sh \
    "git push --force origin main" \
    MYSYSTEM_HOOKS_ENFORCE=1 MYSYSTEM_ALLOW_FORCE_PUSH=1
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "block-dangerous-git: allows read-only git commands" {
  run run_bash_hook block-dangerous-git.sh \
    "git status" \
    MYSYSTEM_HOOKS_ENFORCE=1
  [ "$status" -eq 0 ]
}

@test "block-dangerous-git: default mode is dry-run (logs, exits 0)" {
  run run_bash_hook block-dangerous-git.sh \
    "git reset --hard"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
}

@test "dangerous-command-blocker: blocks rm -rf on a system path in enforce mode" {
  run bash -c 'printf "%s" "{\"tool_input\":{\"command\":\"rm -rf /etc\"}}" |
    MYSYSTEM_HOOKS_ENFORCE=1 python3 "'"$HOOKS"'/dangerous-command-blocker.py"'
  [ "$status" -eq 2 ]
}

@test "dangerous-command-blocker: allows rm -rf under /tmp (whitelisted)" {
  run bash -c 'printf "%s" "{\"tool_input\":{\"command\":\"rm -rf /tmp/scratch\"}}" |
    MYSYSTEM_HOOKS_ENFORCE=1 python3 "'"$HOOKS"'/dangerous-command-blocker.py"'
  [ "$status" -eq 0 ]
}

@test "env-file-protection: blocks Write to .env.production.local in enforce mode" {
  run bash -c 'printf "%s" "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/tmp/proj/.env.production.local\"}}" |
    MYSYSTEM_HOOKS_ENFORCE=1 python3 "'"$HOOKS"'/env-file-protection.py"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "secret-scanner: blocks git commit when staged diff contains a provider key" {
  cd "$BATS_TEST_TMPDIR"
  git init -q scanrepo && cd scanrepo
  git config user.email t@t && git config user.name t
  # Assemble the fake key at runtime so this test file never contains a
  # literal that would trip the scanner on MySystem's own commits.
  printf 'token = sk-ant-%s\n' "$(printf 'a%.0s' $(seq 1 70))" > config.txt
  git add config.txt
  run bash -c 'printf "%s" "{\"tool_input\":{\"command\":\"git commit -m x\"}}" |
    MYSYSTEM_HOOKS_ENFORCE=1 python3 "'"$HOOKS"'/secret-scanner.py"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"Anthropic"* ]]
}
