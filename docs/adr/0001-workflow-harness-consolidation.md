# ADR-0001: Workflow harness consolidation — adopt over build

- **Status**: Accepted
- **Date**: 2026-05-17
- **Author**: seungwon-v6x
- **Tags**: workflow, philosophy, ship-discipline

## Context

By v0.29.x MySystem was carrying:
- 5 user-owned skills under `skills/` (slow-down, search-first, documentation-lookup, bugbot, verify-test)
- 20 subagent definitions under `agents/` (none ever invoked by the workflow)
- 31 SuperClaude `sc:*` slash commands under `commands/sc/` (a parallel system)
- A 9-step workflow that referenced `/slow-down` (now redundant with `/autoplan`'s plan-writing phase) and `/bugbot` (a user-owned skill duplicating obra/superpowers behavior)

Every session start surfaced ~100+ available skills. The coordinator (Claude) had to triage which to invoke; the user had to remember which ones were actually in the workflow. The result: scope sprawl, occasional invocation of off-workflow skills, and a growing maintenance burden on user-owned code that wasn't really paying for itself.

## Decision

We will **adopt** external skills via a thin harness (`setup.sh` + `settings.json`) and **resist building** new ones. New workflow needs go through three filters in order: (1) is there a public skill that fits? (2) can we cherry-pick the one skill we need without inheriting siblings? (3) only if both are no, write a user-owned skill in `skills/<name>/` and whitelist it in `.gitignore`.

Boundary: this ADR governs the workflow harness shape, not individual skill choices (those are CHANGELOG events).

## Alternatives considered

- **A: Keep growing user-owned skills under `skills/`** — rejected because every skill is a maintenance liability and the harness philosophy converges to "fork everything" at scale
- **B: Wholesale adopt a single framework (SuperClaude, BMAD, spec-kit)** — rejected because they take over the workflow and bugs in their process become bugs in ours; see [.out-of-scope/superclaude-parallel-system.md](../../.out-of-scope/superclaude-parallel-system.md)
- **C: Stay with the v0.29.x sprawl** — rejected because the agent-skill surface was the dominant source of off-workflow drift

## Consequences

- ✓ Workflow surface collapses from ~100 skills + 20 agents + 31 sc:* commands to a known whitelist mapped step-by-step in CLAUDE.md
- ✓ Skill upgrades come for free via `git pull` in upstream repos; MySystem only edits its own ~50-line `setup.sh`
- ✗ External upstreams can break or sunset; MySystem assumes that risk in exchange for low maintenance (mitigation: prefer high-star, recently-pushed sources, validate at adoption time via /office-hours + /deep-research)
- ? Whether the "skill whitelist" rule survives contact with skills that legitimately want to fire outside the 8-step workflow (already needed one exception in v0.33.0 for learning-opportunities-auto's PostToolUse hook; watch for a second one)

## References

- Related: ADR-0002 (sparse cherry-pick mechanism), ADR-0005 (plugin marketplace)
- CHANGELOG: v0.30.0
- Inspired by: mattpocock/skills `.out-of-scope/` discipline
