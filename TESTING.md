# Testing

Tests let MySystem's harness-level guarantees stay guarantees. The prompt layer
can rot under context pressure; the hooks must not. Every safety hook gets a
behavioral test of its real process contract — JSON on stdin, exit code out.

## Framework

[bats-core](https://github.com/bats-core/bats-core) (installed via
`brew install bats-core`; CI uses the apt package).

## Run

```bash
bats tests/            # whole suite, <5s
bats tests/hooks.bats  # just the PreToolUse hook contracts
```

CI runs the same suite on every push and PR (`.github/workflows/test.yml`)
with `CLAUDE_HOME` pointed at the checkout.

## Layers

- **Hook contract tests** (`tests/hooks.bats`) — drive each defense-in-depth
  hook (`hooks/*.py`, `hooks/*.sh`) as a real subprocess: enforce-mode blocks
  exit 2, dry-run default exits 0, allow-paths exit 0. The hard-refuse cases
  (force-push to main with the bypass env set; staged provider keys) are the
  highest-value tests in the repo — they pin the prompt-injection defenses.
- **Script smoke tests** (`tests/scripts.bats`) — repo utility scripts run
  clean against a tracked-files-only tree (what CI sees).

## Conventions

- One behavior per `@test`; name states the behavior, not the function.
- Hooks are tested through their process boundary, never by sourcing.
- Never put a literal secret-shaped string in a test file — assemble fake
  keys at runtime (see `secret-scanner` test) or the scanner blocks the
  repo's own commits.
- Tests requiring a git repo create one under `$BATS_TEST_TMPDIR`.
