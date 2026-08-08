# ADR-0023: Rewire Step 1 to a skill that accepts ordinary changes; hold the enforcement hook

- **Status**: Accepted
- **Date**: 2026-08-07
- **Author**: seungwon-v6x
- **Tags**: workflow, skills, measurement, harness

<!-- mysystem:managed-start (intentionally empty — reserved for future tooling) -->
<!-- mysystem:managed-end -->

## Context

The owner reported that fresh worktree sessions skip Step 1 and go straight to
implementation. Investigation found the report correct and produced two findings,
one of which corrected the other.

**The mis-wire.** `CLAUDE.md` mapped Step 1 to gstack's `/office-hours` for every
Feature / Bug Fix / Refactoring. That skill lists its proactive-invocation
triggers as "a **new product idea** … something that **doesn't exist yet** …
**before any code is written**" (`skills/gstack/office-hours/SKILL.md:61-63`,
quote verified). Precisely: those lines are a trigger list, not a prohibition —
nothing in the skill's 1697 lines forbids using it on existing code. But for
"change this button's copy" the mapping and the skill's own triggers disagree, and
the model resolves that in favour of the more specific instruction. The file is
gstack-owned, so `gstack-upgrade` overwrites any local edit. Sessions that did run
Step 1 skewed toward the ones matching `/office-hours`' stated triggers.

**The measurement, corrected twice.** The first pass reported a decay to 12% and
concluded that three consecutive prose-only restorations had failed. That was an
artifact of bucketing by calendar week using file **mtime**, which smeared across
the ADR-0021 commit boundary. The second pass split at commit boundaries using
session **start** time but omitted the ADR-0015 / ADR-0016 pair, which blended
three configurations into one "48% baseline" — the same error in a smaller form.
Both were found by review, not by the author. With every boundary listed and
synthetic probe sessions excluded (`scripts/measure-step1.py`):

| Config window | Sessions | Step 1 ran before the first edit |
|---|---|---|
| pre-ADR-0015 (rule present) | 13 | **46%** |
| ADR-0015, rule deleted (07-13 18:51) | 12 | **8%** |
| ADR-0016, rule restored (07-21 13:58) | 27 | **62%** |
| ADR-0019, rule deleted again (07-30 15:21) | 38 | **0%** |
| ADR-0020, restored as description only (08-05 16:27) | 9 | **0%** |
| ADR-0021, rule restored (08-06 16:13) | 16 | **31%** |

```
corpus  2026-06-12T19:05 .. 2026-08-08T23:38   115 counted of 259 seen
        excluding: claude-501, scratchpad   generated 2026-08-08T23:48
```

**This table is a dated snapshot, not a finding, and it decays.** Transcripts are
retention-pruned (`cleanupPeriodDays` is unset everywhere, so the 30-day default
applies). The pre-0015 window fell from 19 sessions to 13 within a single hour of
review, and by 2026-08-13 the retention edge reaches 07-14 — past the ADR-0015
boundary — so the two windows that anchor the "rule present" band will be gone or
thinned to nothing. Quote the corpus line with any number, or the number means
nothing.

The boundaries themselves are approximate. They are timed from when each
CLAUDE.md landed on disk in `~/.claude` (which is the live repo, developed in
place) rather than from the merge to main — ADR-0021 was readable at 16:13 but
main did not carry it until 18:08. The file is edited before it is committed, so
the true transition is earlier still. Sessions starting within a few hours of a
boundary are unreliable.

Four windows point the same way: rule present 46-62%, rule absent 0-8%. The
direction is consistent across three independent removals and restorations, which
is the part worth trusting. The exact figures are not: this measurement has now
been recomputed five times in one session and produced a different table each
time, as boundaries were corrected and the corpus moved underneath it.

ADR-0021 shipped the day before this investigation, so its 31% rests on n=16 and
proves nothing on its own. The owner's recollection that "it used to work" is
confirmed, and the cause was the deletion, which ADR-0021 already reversed.

Compliance also correlates with task size: 20% at 1-3 edits, 14% at 4-10, 32% at
11-40, 26% above 40 (same snapshot). Confounded, and named as such: 47 of the 115
counted sessions sit in the two 0%-compliance windows, so part of that gradient is
the config gradient, not size. ADR-0021 anticipated exactly this and named the
lever: "If the friction is worse than the drift, the lever is to widen the
carve-out, not to re-soften the mapping."

A `PreToolUse` enforcement hook was planned, reviewed, and rejected. Both review
voices reached "do not ship as written" independently. Decisive objections:

- The trigger evaporated with the corrected measurement.
- ADR-0019's pre-registered kill criterion comes due **2026-08-13**. Building
  machinery on the assumption that mandatory invocation fails, six days before the
  answer arrives, is backwards.
- ADR-0015 already built this hook — `tier-guard`, with a state file, size budget,
  declaration CLI, and 17 passing bats contracts — then deleted it. Its recorded
  rejection reads as a review of the new plan: "it relocates gates into hooks
  rather than removing them … for an operator whose complaint was harness weight,
  violating trigger-driven shipping — it ships permanent machinery to test whether
  misclassification is even a real problem."
- The success metric was invocation rate, a process-volume number with no harm
  term. `CLAUDE.md` *No self-scored improvement loops* forbids that shape.
- The plan had no triviality carve-out, so enforce mode would have blocked the
  typo fixes `CLAUDE.md` explicitly permits, and the only escape was unsetting an
  env var — which is how a guard gets disabled permanently.

Two empirical findings from that review survive and are recorded here because they
contradict the vendor documentation and will otherwise be rediscovered:

- **`Skill` IS matchable by a hook.** `code.claude.com/docs/en/hooks` states "Skill
  tool matchable: **No** — Skill is not a tool event". Measured on CLI 2.1.223 with
  probe hooks in an isolated project: `PreToolUse` and `PostToolUse` with
  `matcher: "Skill"` both fire and carry `tool_input.skill` plus `prompt_id`.
- **A user-typed `/skill` fires no hook at all.** Typing `/probeskill` produced zero
  hook events. Any future guard keyed on `Skill` must also read `UserPromptSubmit`,
  or it will deny a user who genuinely ran Step 1 by typing it.

Also verified, against the docs' silence: `permissions.deny` applies under
`bypassPermissions`. A whole-tool deny removes the tool ("disabled for this
session, in subagents as well as here"); `Bash(sed:*)` is denied at call time.

## Decision

Two things, and deliberately only two.

**Rewire Step 1.** Add a user-owned `skills/scope-check/` and make it the default
Step 1: restate the request in three lines, name what is out of scope, ask one
question only if a reading is genuinely ambiguous. It writes nothing and invokes
nothing. `/office-hours` stays mapped for work that does not exist yet;
`/investigate` keeps the debug branch. Step 1 is satisfied by exactly one of the
three, chosen by what the request is. Both instruction surfaces change together
per *Detailed Rules*.

**Hold the enforcement hook until 2026-08-13.** No hook, no `settings.json`
matcher, no contract tuple. On that date run
`scripts/measure-step1.py --since 2026-08-06T18:08` over the week of post-ADR-0021
sessions, and read it against the 46-62% with-rule band rather than a round
number:

- **≥ 50%** — treat ADR-0021 as working. No hook, and this ADR closes.
- **≤ 25%** — the prose is not holding. Start with context re-injection
  (`UserPromptSubmit` / `SessionStart` `additionalContext`), not a deny path:
  re-injection answers decay without a false-positive surface, so it cannot become
  "so noisy it gets turned off".
- **anything between, or n < 20, or the corpus line shows a window has been
  pruned away** — re-measure later. Do not decide.

This is a re-measure trigger, not a decision procedure, and it is deliberately
weaker than the version first written here. A rule that reads a threshold off a
sample this small, from a corpus that shrinks daily, would just be the sixth
different number in this ADR's history wearing a decision's clothes.

**The harm metric is still missing, and this ADR does not fix it.**
ADR-0019 pre-registered a criterion citing `scratchpad/drift.py` (REDIRECT+REMOVE
share vs 79%, post-code share vs 71%); that script is gone from disk and
`measure-step1.py` does not compute it — invocation rate is a different metric.
So the ADR-0019 criterion remains unexecutable, exactly as unexecutable as it was
before this change. The decision rule above therefore turns on the Step-1 rate
alone. Reconstructing the harm measurement is the more valuable piece of work and
is listed in *NOT in scope* rather than pretended to be done.

What `scripts/measure-step1.py` does fix is reproducibility of the one number it
computes. Two bucketing errors in two passes, both caught by review rather than by
the author, is the argument for committing it: an unreproducible measurement does
not get to justify a change.

This decision does not widen the triviality carve-out, does not touch the Step-1
obligation itself, and does not revisit approval waits.

## Alternatives considered

- **Ship the `PreToolUse` guard now** — rejected; see Context. Kept viable: the
  correct mechanism is a `(session_id, prompt_id)` marker written by
  `PostToolUse(Skill)` **and** `UserPromptSubmit`, checked by
  `PreToolUse(Edit|Write|MultiEdit)`. O(1), race-free, per-request.
- **Bash write-detection inside the guard** — rejected outright, not deferred.
  `prettier --write`, `make`, `git apply`, `patch`, `perl -pi`, `> "$f"` and dozens
  more defeat any command-string pattern list, while the false-positive surface
  (`grep '>' f`, heredocs) arrives in full. A leaky detector here is worse than
  none: it advertises coverage it does not have.
- **Widen the triviality carve-out instead** — the lever ADR-0021 names, and a real
  option. Held because the size data (16% small / 30% large) suggests the model is
  already weight-matching, so widening the carve-out may only ratify current
  behavior. Revisit on 08-13 with the same numbers.
- **Adopt tdd-guard** — rejected. LLM-based validation where determinism is wanted;
  requires Node 22+ plus a supported test framework and reporter integration (this
  repo is bash + bats); rules configurable only within the TDD domain.
- **Reword `CLAUDE.md` harder** — rejected. Three attempts (0019→0020→0021) already
  address wording; a fourth changes nothing the third did not.

## Consequences

- ✓ Step 1 has a skill that accepts the request class it is mapped to. The routing
  invariant is guarded by `tests/step1-routing.bats`, scoped to the mapping rows so
  wording is free but routing is not, and asserting that the FIRST Step-1 row names
  `/scope-check` — precedence, not presence. Two earlier versions of that file did
  not guard it: the first passed a byte-identical revert, the second passed a
  semantic one that made `/office-hours` the default again while still naming all
  three skills. Both were found by review, not by the author. The third version
  fails against that exact revert.
- ✓ The measurement is committed and prints its own corpus range, count, and
  exclusions, so a future number can at least be compared against a stated
  baseline instead of a remembered one.
- ✗ **It is not reproducible over time and this ADR no longer claims it is.**
  Retention pruning removes the oldest window daily; five recomputations in one
  session produced five tables. Re-running on a later date measures a different
  corpus, and only the printed fingerprint makes that visible.
- ✓ Two vendor-doc contradictions are recorded with the method used to find them,
  so a future guard starts from measurement rather than from the docs.
- ✓ One change ships, so if the Step-1 rate moves it is attributable. Bundling the
  rewiring with a hook would have made attribution impossible.
- ✗ Six more days of skipped Step 1 if ADR-0021 is in fact not working. Accepted:
  the cost of waiting is bounded and the cost of permanent unused machinery is not.
- ✗ A fourth user-owned skill is a fourth thing to keep current, and `/scope-check`
  overlaps `/office-hours` at the edges. Mitigated by putting the routing table in
  the skill itself, testing it, and settling the one genuinely ambiguous case (a new
  file inside an existing product) in a line both surfaces carry verbatim.
- ✗ `scripts/measure-step1.py` undercounts: a Step-1 skill the user *typed* emits no
  `Skill` tool call, so those sessions score as non-compliant. Every number it
  reports is a floor. Documented in the module docstring.
- ✗ **The Codex global projection now has 95 bytes of slack** before
  `GLOBAL_BUDGET_EXCEEDED` (32673 of a 32768 payload limit). It had 424 before this
  change. The next sentence added to `codex/workflow-contract.md` fails the render,
  which is why the disambiguation rule is one compressed line and the Codex Step-1
  rule is one compressed line rather than the full paragraph carried on the Claude
  surface. To be exact about what was traded: the Codex Step-1 rows **grew** (two
  rows to three, 106 → 158 bytes) and the projection grew 329 bytes net; the saving
  came from compressing the disambiguation paragraph, not from shortening the rows.
  Raising `global_max_bytes` was rejected: the budget encodes an observed
  compatibility baseline, so raising it to fit is weakening a check to get
  unblocked.
- ✗ `scripts/claude-md-budget.sh` had been reporting the LIVE install's numbers when
  run from a clone, so it printed 4520 bytes of headroom for a checkout whose real
  figure was 4276 — cited as evidence twice before review caught it. Now defaults to
  its own checkout.
- ? Whether 40% on n=10 holds. That is the whole bet, and 08-13 settles it.

## References

- Related ADR: ADR-0015 (built and deleted `tier-guard`), ADR-0016, ADR-0019
  (removed the waits, pre-registered the 08-13 criterion), ADR-0020, ADR-0021
  (restored mandatory invocation)
- Code: `skills/scope-check/SKILL.md`, `scripts/measure-step1.py`, `CLAUDE.md`
  (Step → Skill mapping, Complete Workflow, Skills whitelist),
  `codex/workflow-contract.md`, `codex/parity-contract.json`
- Tests: `tests/step1-routing.bats`
- Vendor docs contradicted by measurement: `code.claude.com/docs/en/hooks`
  ("Skill tool matchable: No")

## How this file is maintained

- ADR numbering is monotonic per project. Don't reuse numbers; mark superseded instead.
- Rewrite history only by adding a new ADR that supersedes the old one.
- An ADR is deliberate. Don't auto-generate from PR descriptions.
