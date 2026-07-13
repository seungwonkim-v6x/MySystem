# Testing

MySystem has deterministic CI contracts and a separate bounded live release
gate. Setup, CI, and SessionStart never launch a model, browser, or authenticated
MCP operation.

## Framework

[bats-core](https://github.com/bats-core/bats-core), `jq`, and the runtime's
standard Bash/Python tools.

```bash
brew install bats-core jq       # macOS
sudo apt-get install bats jq    # Ubuntu
```

## Run

```bash
bats tests/                       # complete deterministic suite
bats tests/codex-parity.bats      # projection/installer/doctor contracts
bats tests/hooks.bats             # hook payload and exit contracts
bats tests/ai-review-loop.bats    # Step 9 helper contracts
./setup.sh --check                # live filesystem structural check
```

The parity contract group takes about 15 seconds on the reference macOS host;
the full suite is intentionally broader than the former sub-five-second hook
suite. CI runs Ubuntu and macOS jobs on every push and pull request.

## Deterministic layers

- **Projection:** marked source closure, declaration/manifest agreement,
  deterministic hashes, LF/final-newline policy, stale detection, separate
  global/project byte budgets, exact hook-contract closure, and project-rule
  isolation.
- **Installer:** fresh/repeat runs, paths with spaces, absent/correct/wrong/
  broken links, empty placeholders, approved migration/backup/recovery,
  content-identity recovery, unknown-content preservation, unsafe state/lock
  leaves, unsafe homes, and complete preflight before link mutation.
- **Doctor:** stable fields and exit codes, core skill ownership, hook semantic
  requiredness, malformed-contract JSON summaries, optional profiles,
  supported/missing MCP/plugin inventory, and configured-versus-live distinction.
- **Hooks:** real subprocess payloads, default dry-run behavior, enforced blocks,
  malformed-input behavior, and unconditional hard refusals for force-push to
  main/master and private-key commits.
- **Step 9 helpers:** reviewer detection, pagination, fingerprints, budget and
  sensitive-path gates, posting safety, and convergence state.
- **Documentation:** current generated files and deny-patterns for disproven
  shared-cap/CLAUDE-only claims.

Fixture tests set `HOME`, clear `CODEX_HOME`, and call the isolated parity
installer directly. They never run gstack setup or use the developer's live
runtime directories.

## Manual behavioral release gate

A release cannot claim Claude/Codex parity until both ordinary Codex and
Orca-hosted Codex pass these bounded scenarios in an unrelated temporary repo:

1. A feature request routes to `/office-hours`, writes no implementation, and
   stops for approval.
2. A debug report routes to `/investigate` and presents 3-5 ranked falsifiable
   hypotheses before instrumentation.
3. One explicit approval advances exactly one workflow step. A skip occurs only
   when the user explicitly requests it.
4. Step 5 presents the configured menu and always invokes
   `/verification-before-completion`, including Skip.
5. Material UI work runs the `material-ui` preflight; browser verification runs
   the `browser` preflight and non-mutating live capability check.
6. `/ship` advances to Step 9 only when it created a PR.
7. A MySystem session receives repo self-management rules; an unrelated repo
   does not.

Record observed step/skill/tool/state events and forbidden actions. Do not
assert exact model wording.

## Harmless hook dispatch canary

After reviewing/trusting hooks in each runtime, use an isolated temp repository:

- run a harmless read-only shell command and confirm all Bash safety hooks
  dispatch without blocking;
- create/edit a non-secret temporary Markdown file and confirm the edit safety
  hook plus convenience renderer dispatch;
- submit a known blocked command only through the existing hook fixture payload,
  not against a real system path;
- for Orca, start a new Codex session before the canary so its host-owned merged
  registration is fresh.

Structural tuple presence is necessary but does not replace this dispatch proof.

## Performance baselines

Measure locally without telemetry:

```bash
time ./setup.sh --check
time ./setup.sh --parity-only   # warm repeat
time ./setup.sh doctor
time bats --filter "fresh install" tests/codex-parity.bats
```

The target is a warm parity install under five seconds and a read-only core
check under one second on the reference machine. External gstack/network time is
reported separately and is not part of the parity target.

Observed on 2026-07-10 with Codex CLI 0.144.1 after review hardening:
steady-state read-only check `0.92s`, warm parity install `2.27s`, core doctor
`1.13s`, and the isolated fresh-install fixture including its idempotent repeat
`5.33s`. The full parity Bats group is tracked separately from these four local
time-to-hello-world baselines.

## Live release evidence — 2026-07-10

Ordinary Codex and Orca Codex were both exercised from an unrelated temporary
Git repository against Codex CLI 0.144.1 and the Orca 1.4.128 compatibility
baseline:

- feature requests selected `/office-hours` and stopped for its first decision;
- debugging requests selected `/investigate` and presented four ranked,
  falsifiable hypotheses before testing them;
- explicit Step 1 approval selected only `/deep-research`, never Step 3;
- the UI-free Step 5 menu omitted design review and always retained
  `/verification-before-completion`, including on Skip;
- a PR-producing `/ship` selected only Step 9 `/ai-review-loop`;
- material UI and browser questions named the exact `doctor --require` profile
  plus `/frontend-design` or `/aside-qa` respectively;
- unrelated repositories rejected MySystem-only repo rules, while the MySystem
  checkout loaded the logical-change commit rule and PostToolUse git ban.

The ordinary and Orca hook canaries each dispatched all three Bash safety hooks
and the Edit safety hook through real Codex shell/apply-patch tool calls. Aside
MCP was structurally registered in ordinary Codex; Orca used its declared CLI
fallback after host refresh. Both browser profiles passed, and a non-mutating
live `listBrowserTabs()` call succeeded through Aside CLI.
Figma remains structurally configured but live authentication is intentionally
reported as unverifiable until an explicit Figma workflow authenticates it.

## Conventions

- One behavior per `@test`; names state behavior, not implementation.
- Exercise hooks and installers through their process boundary.
- Never include a literal secret-shaped value; assemble fake tokens at runtime.
- Create Git repos and runtime homes only under `$BATS_TEST_TMPDIR`.
- Clear inherited `CODEX_HOME` in fixture tests before discovery.
- Every warning/failure `docs` field must resolve to a `SETUP.md` heading.
