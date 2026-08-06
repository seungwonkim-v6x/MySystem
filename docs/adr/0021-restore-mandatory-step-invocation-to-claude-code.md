# ADR-0021: Restore mandatory step invocation to the Claude Code surface, still without the approval gates

Date: 2026-08-06
Status: Accepted
Amends: ADR-0020 (restore the step scaffolding). Partially reverses ADR-0019's thinning of
`CLAUDE.md` — the surface split itself stands. Does not touch ADR-0016 (Codex keeps its
gates), ADR-0017 (Step 6/7 merge), ADR-0018 (no Step 9), or ADR-0006 (hooks).

## Context

ADR-0020 restored the step→skill mapping, the Complete Workflow, the Step 5 menu, and the
Step 6 review to `CLAUDE.md`, but deliberately restored them as *description*, not as
obligation. Two sentences carried that choice:

- `## Default Order (**a default, not a contract**)` … "Skip steps to match the weight of
  the task, and say in one line what you skipped."
- Under the mapping: "This table says **which** skill owns a step, **not that every step
  runs**. *Default Order* decides whether a step runs at all."

The owner asked why Claude Code was not starting from `/office-hours`. The answer was that
nothing on the Claude Code surface required it to. The mandatory-invocation clauses that
did — "ZERO discretion to skip or reorder", "IF A WHITELISTED SKILL APPLIES … YOU MUST
INVOKE IT BEFORE RESPONDING" — were moved out by ADR-0019 and now exist only in
`codex/workflow-contract.md` (lines 16 and 26). ADR-0020 saw the risk and named it: a
verbatim restore of the mapping's absolutist sentence "would cancel *Default Order*'s
'Skip steps to match the weight of the task' and restore the gated contract through the
back door." It resolved the tension by keeping *Default Order* and scoping the mapping.
This ADR resolves it the other way.

Two things narrow what should change:

1. **The gates are not what was missing.** ADR-0019's measurement (58 sessions, 77
   corrections) found 71% of course-corrections arriving *after* code was written and only
   31% of sessions reaching `/ship`. The six approval waits were the part that measured
   badly. Nothing in that measurement implicates mandatory *invocation*, which is a
   separate mechanism: one says which work happens, the other says who waits between.
2. **Request Lock was built for a different complaint.** 79% of the same corrections were
   scope, not defects. Deleting Request Lock to get step invocation back would trade one
   measured problem for another. It stays.

One factor sits outside this repo: the Claude Code harness injects a session-level line,
"Do not use workflows or deep-research unless the user requested it," which is not present
anywhere in `~/.claude/` and independently suppresses Step 2. `CLAUDE.md` is prompt-level
(precedence 3b) and the harness line is a provider-side default, so this ADR cannot settle
that conflict; it is recorded here so the next investigation does not re-derive it.

## Decision

Restore to `CLAUDE.md`, under a new `## Critical Workflow Rules` heading placed after
Request Lock and before *Default Order*:

1. The **ZERO discretion / MANDATORY** paragraph, verbatim from `codex/workflow-contract.md`
   line 16 — including "NEVER write code before `/autoplan` is done" and "NEVER ask the
   user 'should we skip?'".
2. The **Skill whitelist** paragraph, verbatim from line 26, including "YOU MUST INVOKE IT
   BEFORE RESPONDING. Even minimal probability requires invocation."
3. The **Triviality carve-out**, verbatim from line 28. This is the only escape valve
   restored, and it is deliberately narrow: typo, single-character, comment-only,
   single-symbol rename, or work the user framed as trivial.
4. The **`Autonomous (in whitelist)` carve-out** from v0.54.0's sparse-skill policy, naming
   `/verification-before-completion`, `/aside-qa`, and `/frontend-design` (the last
   materiality-gated). Without it, paragraph 2's "only skills mapped to workflow steps"
   contradicts the Step 4 and Step 5 text, which invokes all three autonomously and does
   not list them in the mapping table. Caught by the pre-landing review, not the original
   draft.

And correspondingly:

5. `## Default Order (a default, not a contract)` → `## Default Order`; its "Skip steps to
   match the weight of the task" paragraph is deleted. The "Never ask 'should we run step
   N?'" instruction is not lost — it is covered by the restored paragraph 1.
6. The mapping's scoped sentence reverts to v0.54.0's: "The agent **must** call exactly
   these skills for exactly these steps. Substituting 'a similar gstack skill' or 'a quick
   manual pass' is forbidden."
7. `## Skills` relabels its list from "available when they fit" to "the
   autonomous-invocation whitelist", pointing at *Critical Workflow Rules*.
8. *Default Order*'s large-feature paragraph is rewritten from "the heavier path is an
   interview, **not a review panel**" to "`/autoplan` is **not enough on its own**: also
   interview the user…". The original framed the interview as a substitute for the review
   panel, which now reads as routing around a mandatory step. Also a review finding.

Explicitly **not** restored from v0.54.0: the `↓ (wait for user approval)` arrows, the
`NEVER proceed … without explicit user approval` paragraph (contract line 18), the
Auto Mode subordination paragraph (line 20, whose text asserts gates that no longer
exist), the Instruction Precedence table, the Workflow Successor Map, and the
`mysystem:section` projection markers. Kept intact from ADR-0019: Request Lock, the
self-scored-loop ban, the named gstack `Boil the Ocean` override and its watchdog test,
and the three anchors in `rules/operating-principles.md`.

One paragraph is new, with no v0.54.0 counterpart, and is recorded as a deviation because
a verbatim restore would have been ambiguous without it: **"Steps are mandatory; step
transitions are not gated."** In v0.54.0 the "runs in order" language sat directly above
the approval-gate paragraph and inherited its meaning from it. Restored alone, "every step
is MANDATORY and runs in order" reads as re-implying the gates ADR-0020 rejected. The
paragraph states the split and points at *Short Loop*. A second short line states that
Request Lock binds inside every step, so that "mandatory step" is not read as license to
widen what the step covers.

The Codex surface is untouched. `codex/workflow-contract.md` keeps the full gated contract
as the `AGENTS.global.md` projection source. The two surfaces now agree on step content and
on mandatory invocation. They still differ in both directions: Codex alone carries the
approval gates, the Instruction Precedence table, and the Workflow Successor Map; Claude
Code alone carries Request Lock, the self-scored-loop ban, and the named gstack override.

Because "the two surfaces agree" is the load-bearing claim and nothing enforced it,
`tests/mandatory-invocation.bats` is added on the pattern v0.55.0 used for the named
override: it locates each of the three paragraphs in the contract by a unique anchor
phrase and asserts `CLAUDE.md` carries that exact line, so a reword on either side turns
the suite red. A fourth test asserts the negative — that the Codex-only approval-gate
paragraph never appears in `CLAUDE.md` — since a leak there would silently collapse the
split back into the gated contract ADR-0019 rejected. Both directions were verified by
injecting drift into a throwaway copy and confirming the suite goes red.

## Consequences

- **This conflicts with the owner's own logged feedback** that running
  `/office-hours` → `/deep-research` → `/autoplan` on a ~30-line personal-infra change is
  over-process. That feedback is not withdrawn by this ADR; it is now carried entirely by
  the triviality carve-out, which does not cover a 30-line infra change. Expect friction on
  small changes, and expect the user to interrupt — which the restored text explicitly
  names as their job. If the friction is worse than the drift, the lever is to widen the
  carve-out, not to re-soften the mapping.
- `CLAUDE.md` grows from 11,471 B to 13,164 B; `scripts/claude-md-budget.sh` puts the
  always-loaded total at 23,336 B → 25,029 B. The Codex global projection is unchanged at
  32,344 B — 424 B under the 32,768 B compatibility payload limit, 4,520 B under the
  36,864 B absolute ceiling — because `CLAUDE.md` stopped being a projection source in
  ADR-0019.
- ADR-0019's kill criterion still applies and now measures a third configuration:
  scaffolding present, invocation mandatory, gates absent. Re-run `scratchpad/drift.py`
  against the 79%-scope / 71%-after-code baselines. Two signals to watch, in opposite
  directions: `/ship`-reaching sessions should rise above 31%, and REDIRECT corrections
  should *not* climb back toward 47% — if they do, mandatory invocation is re-importing the
  scope drift Request Lock was built to stop.
- Versioning: minor, on ADR-0020's reasoning. The mapping's content is unchanged; what
  changes is its binding force. 1.0.0 would assert a stability promise this repo moved into
  `0.x` to avoid.

## Rollback

Delete `## Critical Workflow Rules` from `CLAUDE.md` and restore the two ADR-0020 sentences
(`## Default Order (a default, not a contract)` with its "Skip steps" paragraph, and the
mapping's "This table says which skill owns a step" note). `git show 56037b4:CLAUDE.md`
holds the exact pre-ADR-0021 text; `codex/workflow-contract.md` keeps the restored clauses
regardless, so nothing is lost by reverting.
