# Testing

Tests pin the safety hooks' real process contract — JSON on stdin, exit code
out — so the behavior can't silently rot under prompt-context pressure. Note
the hooks run **dry-run by default** (`MYSYSTEM_HOOKS_ENFORCE` is unset on
purpose; Auto Mode's permission gate is the live risk adjudicator). What
always blocks regardless of mode is the two hard-refuse tiers (force-push to
main/master, private-key commit). The tests exercise both the enforce-mode
block path and the default dry-run path so a regression in either surfaces.

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
  exit 2, dry-run default exits 0, allow-paths exit 0, malformed stdin fails
  open. The highest-value cases are the two hard-refuse tiers — force-push to
  main even with the bypass env set, and a staged private-key header — since
  those block in any mode and are the parts that don't depend on enforce being
  on.
- **Script smoke tests** (`tests/scripts.bats`) — repo utility scripts run
  clean against a tracked-files-only tree (what CI sees).

## Conventions

- One behavior per `@test`; name states the behavior, not the function.
- Hooks are tested through their process boundary, never by sourcing.
- Never put a literal secret-shaped string in a test file — assemble fake
  keys at runtime (see `secret-scanner` test) or the scanner blocks the
  repo's own commits.
- Tests requiring a git repo create one under `$BATS_TEST_TMPDIR`.
