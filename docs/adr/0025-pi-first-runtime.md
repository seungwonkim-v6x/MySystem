# ADR-0025: Make Pi the canonical runtime

Date: 2026-08-21
Status: Accepted
Supersedes: the active-runtime assumptions of ADR-0014 through ADR-0024
Tags: pi, runtime, simplification, safety, context-budget

## Context

MySystem accumulated a Claude Code/Codex workflow, generated Codex projections, a
phase state machine, gstack's full repository, automatic external updates, model
wrappers, host hook injection, and a large parity test surface. The design was
careful in isolation but the live install had become internally contradictory:
Pi was the intended daily runtime while the checkout still optimized for two
other runtimes.

Observed before this decision:

- Claude's always-loaded rule chain was 29KB before skill metadata.
- The Codex global projection was 32,673 of a 32,768-byte payload budget.
- The gstack checkout occupied about 1.2GB, including about 730MB of dependencies.
- `setup.sh doctor --json` reported seven live Codex core-skill failures.
- The phase gate applied only to Claude's direct Write/Edit tools; Codex had no
  equivalent hook and Bash/MCP side effects remained outside the gate.
- Pi already provides native progressive skill disclosure, context compaction,
  project trust, tool-call interception, and model/cache telemetry.

The user explicitly chose Pi for future coding work and asked for the checkout to
be optimized for Pi rather than preserving Claude/Codex workflow compatibility.

## Decision

1. **Pi is canonical.** Pi 0.84.2+ is the supported runtime for this checkout.
   Claude Code/Codex files remain as inert historical material so the migration
   is reversible, but they are not part of the Pi startup path.
2. **Use Pi-native discovery.** `AGENTS.override.md` replaces the legacy
   `AGENTS.md`/`CLAUDE.md` context for this directory. `.pi/APPEND_SYSTEM.md`
   carries only short behavior rules; there is no duplicated workflow contract.
3. **Use progressive disclosure.** `.pi/prompts/` contains optional review,
   verification, and research templates. No skill is mandatory and no workflow
   gate records a phase across turns.
4. **Use native compaction.** Project and global Pi settings enable auto-
   compaction with a response reserve, use `high` rather than `max` reasoning by
   default, bound retries, expose cache misses, and disable install telemetry.
5. **Keep one small safety extension.** `.pi/extensions/pi-safety.ts` blocks
   protected-path writes and catastrophic commands, and requests interactive
   confirmation for high-impact operations. It never enforces task ordering,
   plan approval, review invocation, or commit policy.
6. **No automatic network setup.** Pi sessions do not run `setup.sh`, gstack
   pulls, package updates, or parity installers. Pi packages and extensions are
   installed explicitly and pinned after source review.
7. **Do not delete runtime data in the migration.** Credentials, browser state,
   Pi sessions, provider state, caches, and legacy external checkouts remain
   user-owned and require a separate retention decision.

## Consequences

### Positive

- The active prompt surface is small and Pi's own progressive disclosure handles
  optional capabilities.
- Context compaction and cache visibility are native rather than simulated by
  custom hooks and budget scripts.
- The model can act directly without six approval transitions or a phase marker.
- Safety still exists at the tool-call boundary, where Pi can show a real dialog
  or fail closed in non-interactive mode.
- Legacy behavior can be compared or restored from Git without being executed by
  ordinary Pi sessions.

### Negative

- Claude/Codex behavioral parity is no longer a goal.
- Pi extensions run with the full user account's permissions; project trust is
  not a sandbox. Untrusted work still needs OS/container isolation.
- The safety extension uses a deliberately small command classification surface;
  it is not a shell parser and should not claim complete coverage.
- Existing legacy files and runtime data still consume disk until separately
  archived or removed.

## Alternatives rejected

- Keep the existing gate and merely add Pi projections: preserves the prompt and
  state bloat while making a third surface.
- Port the full gstack tree: contradicts Pi's progressive disclosure and adds a
  1GB-scale mutable dependency checkout.
- Add a Pi subagent/plan-mode framework: Pi deliberately leaves those choices to
  extensions; the user's complaint is precisely about mandatory orchestration.
- Remove all safety: Pi has no built-in sandbox, so a small confirmation and
  protected-path boundary is a better default than unrestricted automation.

## Verification

The migration is accepted when:

- Pi's resource loader sees the override, project settings, safety extension, and
  only the intended optional prompt templates.
- The extension passes TypeScript syntax/load checks.
- Protected paths and catastrophic shell patterns block; high-impact ordinary
  mutations request confirmation.
- A no-session Pi provider smoke test succeeds.
- No legacy SessionStart updater is part of Pi's resource graph.

## Rollback

Remove or rename `AGENTS.override.md` and `.pi/`, restore the prior tracked
`CLAUDE.md`/`AGENTS.md` state from Git, and restore the previous Pi settings.
Legacy Claude/Codex files were intentionally retained to make this rollback
possible.
