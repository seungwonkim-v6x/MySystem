# ADR-0016: Restore the gated 9-step workflow (reverses ADR-0015)

Date: 2026-07-21
Status: Accepted
Supersedes: ADR-0015 (remove workflow gates)

## Context

ADR-0015 (v0.49.0, 2026-07-13) removed the mandatory 9-step pipeline, per-step
approval gates, skill whitelist, and the /ship auto-chain, reducing CLAUDE.md to
a ~55-line working agreement. Its kill criterion said: restore one targeted rail
after 2-3 real incidents of the same failure.

One week of living with the gate-less agreement produced a different trigger
than the criterion anticipated: the user's day-to-day driver is Codex consuming
the generated `AGENTS.global.md` projection, and the ungated projection made
Codex's behavior noticeably worse — the user reports sustained dissatisfaction
with how Codex sequences and verifies work without the explicit step contract.
The judgment-defaults prose that works acceptably for Claude Code did not
transfer to Codex.

This is a user-outcome call by the repo owner, not a /retro-sampled drift
signal. Per the First Principle (user outcome over existing code), the owner's
explicit decision to restore outranks ADR-0015's incremental-rail guidance.

## Decision

Restore the full gated workflow as it stood at v0.48.0 (a70ea0e), keeping
everything ADR-0015 shipped that is independent of the gates:

- **Restored**: `CLAUDE.md` (9-step pipeline, approval gates, skill whitelist,
  instruction precedence, Step-4 design discipline, /ship→/ai-review-loop
  auto-chain), `codex/AGENTS.header.md` (gated adapter header),
  `rules/repo-self-management.md` (workflow-era semver wording), and the
  gate-era language in `rules/operating-principles.md` (Conditional
  Clarification "Inside a Step", Step-4 references, "during ANY workflow
  step").
- **Preserved from post-v0.48 history**: the First Principle — User Outcome
  Over Existing Code (2ec9213) — kept in `rules/operating-principles.md` and
  therefore in the regenerated projections.
- **Untouched**: all v0.49.0 hook hardening (unconditional hard-refuse tier,
  fail-closed parsing, bypass-resistant matching), the shellcheck CI job, the
  narrowed settings.json git allows, and their bats coverage. ADR-0015's own
  rollback section required exactly this separation.
- **Contract change**: `budgets.global_max_bytes` 32768 → 36864 in
  `codex/parity-contract.json`. The gated projection plus the First Principle
  is 29849 bytes, over the old 28672-byte effective limit (max − reserve);
  reserve stays 4096.

## Consequences

- Codex and Claude Code again share the canonical gated workflow via the
  deterministic projection; `render-codex-agents.sh --check` and the full bats
  suite (136 tests) pass. These are structural checks only — the manual
  behavioral parity scenarios (TESTING.md 1-6, live again per this ADR) have
  not been re-run for v0.50.0 and must run before the next parity claim.
- ADR-0015's kill criterion is retired with the ADR. If the gates chafe again,
  the exit path is a new ADR with its own evidence, not silent drift.
- The v0.49.0 tier-guard middle design remains recoverable from branch history
  and remains rejected.
