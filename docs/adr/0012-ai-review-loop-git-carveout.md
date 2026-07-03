# ADR-0012: Constitutional git-mutation carve-out for /ai-review-loop

Date: 2026-07-03
Status: Accepted

## Context

MySystem's CRITICAL rule said git mutations happen only via `/ship` or
explicit user request. Workflow Step 9 (`/ai-review-loop`, new in v0.46.0)
loops AI reviewers on a PR and must commit and push small fixes
autonomously for the loop to converge — a manual approval per fix (or per
round) breaks the unattended-loop capability that is the feature's point.
The pattern was validated manually on Tapit PR #137 (2026-07-02): 3 rounds
against Copilot, 2 valid fixes, 1 misreading answered.

During `/autoplan` review (2026-07-03), both Claude and Codex reviewers
independently recommended a batched-approval-per-round alternative instead
of a constitutional change. The user heard the case and explicitly chose
full autonomy, twice (v1-scope challenge, then again rejecting a
resource-based pause). Unbounded rounds are likewise an explicit user
decision — do not re-add round or wall-clock caps.

## Decision

Amend the CRITICAL rule to: git mutations happen only via `/ship`,
`/ai-review-loop` within its per-round budget, or explicit user request.

The carve-out is bounded by harness-enforced mechanics, not prompt
discipline:

- Fixes are **staged, never committed**, until
  `skills/ai-review-loop/bin/round-budget.sh --staged` passes.
- ≤20 changed lines per round; >20 pauses for approve / split /
  decline-all. ≤40 changed lines cumulative per loop; beyond that every
  further fix requires the user.
- Sensitive paths (`hooks/**`, `settings.json`, `.github/workflows/**`,
  secret/credential/env globs, `install.sh`, `setup.sh`) and binary diffs
  always escalate regardless of size.
- Loop commits carry the `review-loop(rN):` message prefix (auditable,
  filterable).
- Every escalation pauses the loop as `awaiting-user` with PR-comment +
  push-notification delivery; nothing proceeds silently.

## Alternatives considered (rejected)

1. **Per-fix user approval** — kills loop value entirely; equivalent to
   the manual process the skill replaces.
2. **Batched approval per round before push** (both models' preference) —
   preserves the constitution unchanged at the cost of one interaction per
   round; rejected by the user because unattended operation (loop running
   while away) is the feature's point. The budget gates + awaiting-user
   escalation model deliver the same blast-radius bound without the
   per-round click.
3. **Unlimited autonomy** — unacceptable blast radius; hence the budget +
   sensitive-path mechanics above.

## Consequences

- The constitution now has two autonomous git-mutation holders (`/ship`,
  `/ai-review-loop`). This grant is explicitly non-precedential: future
  workflows citing this ADR still need their own ADR and their own
  harness-enforced bounds.
- The per-PR state file plus PR lifecycle/reply comments (marker
  `ai-review-loop:v1`) are the audit trail.
- **Sunset / re-evaluate trigger:** re-evaluate this skill (and carve-out)
  when any reviewer vendor ships a native "address my own review
  comments" loop covering our tier-A set, or per the v0.44.0 prune rule if
  the skill records zero invocations over a comparable observation window.
