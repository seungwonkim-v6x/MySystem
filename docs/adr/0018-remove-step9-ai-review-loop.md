# ADR-0018: Remove workflow Step 9 (`/ai-review-loop`) — token cost over marginal value

- **Status**: Accepted
- **Date**: 2026-07-28
- **Author**: seungwon-v6x
- **Supersedes / amends**: supersedes ADR-0012 (git-mutation carve-out — its grantee is gone);
  amends ADR-0016's restored step list and ADR-0017's Step 6/Step 9 division of labour
- **Tags**: workflow, token-budget, skills, adr-retirement

<!-- mysystem:managed-start (intentionally empty — reserved for future tooling) -->
<!-- mysystem:managed-end -->

## Context

Step 9 (`/ai-review-loop`, ADR-0012, v0.46.0) auto-chained after `/ship` created a PR: detect
every AI reviewer on the PR, fan out, triage, fix within a budget, reply, re-trigger, loop until
no valid findings remain.

It ran end-to-end for the first time on 2026-07-27 (PR #15, v0.53.0). It worked — 4 rounds, 24
valid findings, converging at zero defects. It caught a false claim that had already shipped
(`render-codex-agents.sh --check` was documented as exiting 0; it exits 1) and caught that PR
violating its own new rail twice by asserting vendor facts without opening the vendor's page.

The cost was the problem:

- 4 rounds × (1 fresh subagent + 1 codex pass), each re-reading the full diff
- 104 changed lines against a 40-line cumulative budget — three separate escalations to the user
- Substantial wall clock and token spend on a documentation-only PR

And the value was structurally capped: **this repo has no tier-A bot reviewers.** No Copilot, no
Greptile, no CodeRabbit — `detect-reviewers.sh` found none on PR #15 or in recent repo history.
So the loop's registry reduced to tier B (codex) and tier C (fresh Claude subagent) — the same two
reviewers Step 6 had just run. Step 9's stated justification (ADR-0017: "Step 6 reviews the
pre-merge diff; Step 9 reviews the PR artifact, because bot reviewers attach to PRs only") assumes
bots exist to attach. Without them, Step 9 is Step 6 again, on a slightly larger diff, N more times.

## Decision

**Remove Step 9 from the workflow and delete the skill.** `/ship` becomes the terminal step, with
no auto-chain and no exception to the per-step approval gate.

Measured token cost recovered (`scripts/claude-md-budget.sh`, 2026-07-28):

| surface | before | recovered |
|---|---|---|
| `CLAUDE.md` always-loaded Step 9 prose | 2,855 B (~713 tokens/session) | all |
| skill `description` in every session's skill list | ~500 B (~125 tokens/session) | all |
| Codex global projection | 31,269 B against a 32,768 B compatibility limit — 5,595 B headroom | ~4,200 B, nearly doubling headroom |
| `tests/ai-review-loop.bats` | 432 lines, 43 of 151 cases | all (suite → 108) |

The Codex line is the one that decided it: the projection sat at 95% of its hard limit, and Step 9
prose was eating the remaining room.

**Deleted, not kept as a user-invoked tool.** ADR-0015 took the lighter path (keep the skill, drop
the auto-chain) and that option was considered again here. It was rejected because it saves almost
none of the above: the step table, the whitelist entry, the skill description, and the carve-out
prose all stay resident whether or not the skill is ever typed. The cost being removed is
*residency*, not invocation.

## Alternatives considered

- **Remove the auto-chain only, keep `/ship`-terminal + `/ai-review-loop` user-invocable**
  (the ADR-0015 shape) — rejected: eliminates runtime cost but ~none of the always-loaded cost,
  which is what was actually being paid.
- **Keep Step 9, add a round cap** — rejected: rounds were deliberately unbounded (user decision,
  twice-affirmed, recorded in the skill). Capping converts "loop until clean" into "loop a bit,
  then stop mid-triage", which is worse than not looping: it leaves a partially-triaged PR and
  still pays the per-round cost.
- **Keep Step 9, gate it on tier-A bot presence** — rejected for now as the most defensible
  variant but not worth its complexity while the answer is always "no bots". This is the shape to
  revisit if bots are ever installed (see below).
- **Do nothing** — rejected: the cost is real, recurring, and paid on every session for a step
  that fired once.

## Consequences

- ✓ ~840 tokens/session off the always-loaded chain; Codex projection headroom roughly doubled.
- ✓ Test suite 151 → 108 cases, 43 fewer contracts to maintain for a deleted feature.
- ✓ The workflow's approval story simplifies to one sentence: every transition is gated, `/ship`
  is terminal. The Step 8→9 auto-chain was the single exception and is gone.
- ✓ ADR-0012's git carve-out retires with it. `/ship` is once again the only skill that commits.
- ✗ **Real coverage is lost, and it caught real bugs on its only run.** Post-PR review is now
  manual: if a bot comments on a PR, read it and decide by hand. The specific class Step 9 was
  good at — catching claims that survived pre-merge review because the author kept re-asserting
  them — now depends on Step 6's two passes being adversarial enough.
- ✗ If PR bot reviewers are ever added to this repo, their findings will accumulate unread unless
  the user looks. That is the honest trade.
- ~ The skill is recoverable from git history (`git show v0.53.0:skills/ai-review-loop/`) plus the
  ADR-0012 reasoning, which is preserved rather than deleted.

## Re-open condition

Restore a *narrower* Step 9 — gated on tier-A bot presence, not auto-chained unconditionally —
when **both** hold: (1) at least one PR-attached bot reviewer (Copilot, Greptile, CodeRabbit, or
similar) is installed on this repo, and (2) a PR ships with a defect that a bot had flagged and
nobody read. Condition (1) alone is not enough; the failure this ADR accepts is *unread bot
findings*, so the trigger is an instance of exactly that.

Do not restore the unbounded auto-chaining shape. If it comes back, it comes back bounded by bot
presence, and the token accounting above gets redone before it lands.

## References

- Supersedes ADR-0012 (git-mutation carve-out). Amends ADR-0016 (restored step list) and
  ADR-0017 (Step 6 vs Step 9 division of labour).
- The one real run: PR #15 (v0.53.0), 4 rounds, closing comment carries the full per-round table.
- Cost measurement: `scripts/claude-md-budget.sh`.

## How this file is maintained

- ADR numbering is monotonic per project. Don't reuse numbers; mark superseded instead.
- Rewrite history only by adding a new ADR that supersedes the old one.
- An ADR is deliberate. Don't auto-generate from PR descriptions.
