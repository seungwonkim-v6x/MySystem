# ADR-0019: Split the Claude Code and Codex surfaces; lock scope to the request; ban self-scored improvement loops

Date: 2026-07-30
Status: Accepted
Amends: ADR-0016 (restore gated workflow) — the gated contract survives, but only on the Codex surface. Amends ADR-0009 (CLAUDE.md trim) with a measured target. Does not touch ADR-0006 hooks.

## Context

The owner reported two symptoms: the workflow felt too heavy, and the agent "does not
do what I said — it changes the scope before I get to change it myself."

Transcript measurement (58 sessions with 3+ workflow steps, `~/.claude/projects/*/*.jsonl`,
scripts kept at `scratchpad/drift.py` / `drift2.py`) found:

- **79% of course-corrections are scope, not defects.** Of 77 corrections: REDIRECT
  ("you built the wrong thing") 47%, REMOVE ("take out what I didn't ask for") 32%,
  RETRY ("it doesn't work") only 8%.
- **71% arrive after code was written.** Six approval gates did not catch direction
  errors, because the owner's work (UI, product, physics sim) is only judgable from a
  result. Gating before a result exists cannot work for it.
- **Only 31% of sessions reach `/ship`.** 24% never run any test or review step. A
  contract honored a third of the time produces unpredictable behavior, which is itself
  the "doesn't do what I said" complaint.
- The largest correction window is `/autoplan` → implementation, and **step 4
  (implementation) invokes no skill**, so it was the one phase with no rule, no
  instrumentation, and no gate.

Three independent causes were then traced, and fixing any one alone leaves the others
producing the same outcome:

1. **Prompt volume.** CLAUDE.md was 19,939 B / 2,722 words, ~30 KB always-loaded with
   the rules files. 34% of the body was rationale, history, and duplicated diagrams that
   change no behavior. Anthropic's own guidance: "Bloated CLAUDE.md files cause Claude to
   ignore your actual instructions."
2. **A direct contradiction with gstack.** Every gstack skill injects
   `## Completeness Principle — Boil the Ocean`, whose claim is that "the only thing out
   of scope is genuinely unrelated work" — i.e. anything *related* is in scope. That is
   the exact opposite of this repo's own `Boil the Lake` rule ("boil lakes, not oceans").
   Precedence said CLAUDE.md wins, but nothing named the conflict, so the nearer and more
   specific text (100 KB loaded at the moment of work) won in practice.
3. **A self-scored improvement loop.** `/autoplan` runs `plan-design-review` at "all 7
   dimensions, full depth", and that skill's `## The 0-10 Rating Method` says: rate 0-10,
   "if it's not a 10 … do the work to get it there", "repeat until 10 or user says 'good
   enough, move on'". The objective function contains no term for the user's request, the
   metric is monotonic in scope, and the exit requires the owner to interrupt. The four
   review voices feeding it (CEO/Eng/Design/DX) are each instructed to find what is
   missing and can only add.

Research (`/deep-research`, report at `scratchpad/research-autoplan-alternatives.md`)
found no third-party planning skill worth swapping in — spec-kit and BMAD are heavier,
Kiro is an editor, OpenSpec adds tooling for an artifact we don't need, and superpowers
`brainstorming` has no lightweight path for small changes. It did find that the fix is
documented and already installed:

- Anthropic names the exact failure: "Without a check it can run, 'looks done' is the
  only signal available, **and you become the verification loop**."
- Anthropic warns against precisely mechanism 3: "A reviewer prompted to find gaps will
  usually report some… Chasing every finding leads to over-engineering."
- The literature is unambiguous: unguided self-refinement gains ≤1.8pp over five
  iterations and often *degrades* output, while externally-guided feedback gains up to
  80% ([arXiv:2310.01798](https://arxiv.org/abs/2310.01798),
  [arXiv:2508.12903](https://arxiv.org/html/2508.12903v1)). A self-scored loop is not a
  weak good loop; it is the failure case.

ADR-0015 already tried removing the gates and was reversed by ADR-0016 — **not because
Claude Code regressed, but because Codex did**: "the ungated projection made Codex's
behavior noticeably worse… The judgment-defaults prose that works acceptably for Claude
Code did not transfer to Codex." Because the parity contract rendered both surfaces from
one source, CLAUDE.md could not be thinned without weakening Codex. That coupling, not
the gates, was the thing blocking a fix.

## Decision

1. **Split the surfaces.** The gated contract moves verbatim to
   `codex/workflow-contract.md` and stays the projection source for
   `codex/AGENTS.global.md`. Codex keeps the 9-step contract ADR-0016 measured it needs;
   Claude Code stops paying for it. Three mechanical changes: the new file, the
   `projections.global.sections` source in `codex/parity-contract.json`, and the
   hardcoded path in `render-codex-agents.sh`'s `declared_skills`.
2. **CLAUDE.md becomes a working agreement, not a contract** — 19,939 B → 6,037 B
   (70% smaller); always-loaded total 29,655 B → 17,902 B (40% smaller). Deleted: the mandatory-
   invocation rule ("Even minimal probability requires invocation"), the skill whitelist,
   the 9-level instruction-precedence list, the triviality carve-out, the successor map,
   the Step-5 A–F menu, and all rationale/history that ADRs already hold. Kept as a
   *default order*, explicitly not a contract: scope → research → design → implement →
   test → review → PR.
3. **Request Lock is the load-bearing rule.** The request sentence is the scope.
   Discovered work is listed under "Not done", never built. Widening requires asking
   first. Feedback is applied to *that feedback only*.
4. **No self-scored improvement loops on the default path.** The 0-10 rating loops in
   `plan-design-review` / `plan-devex-review` / `ios-design-review` run only when the
   user names that skill; `/autoplan` is no longer a mandatory step. Where a skill prints
   `Completeness: X/10`, the score rates coverage inside the locked scope. Every loop must
   state an exit that is not "the user interrupts"; for unattended loops the exit goes in
   code (a `/goal` condition or a Stop hook, both of which stop on an external check).
5. **Name the override instead of patching gstack.** CLAUDE.md quotes the conflicting
   gstack prose by name and supersedes it. gstack's 43 skill files carrying that section are regenerated by
   `gstack-upgrade`, so patching them would silently revert; `--explain-level=terse` was
   rejected because it also deletes `Confusion Protocol`, one of the few drift-*reducing*
   rules. `tests/named-override.bats` fails loudly if the quoted wording disappears, so
   the override cannot go stale unnoticed.
6. **Anchor the two always-loaded principles that licensed the drift.** `First Principle`
   gains: the current goal is the request as stated, and a nearby wrong structure goes in
   "Not done" rather than getting fixed in the same pass. `Boil the Lake` gains:
   completeness is complete *within* the requested scope. `Conditional Clarification`
   gains a retarget — `AskUserQuestion` already runs in 95% of sessions, so the budget
   moves from taste-after to spec-before.
7. **Keep the cheap wins from the research**: skip the plan when the diff fits in one
   sentence; for large features use an interview → self-contained spec (naming files,
   stating out-of-scope, ending in an end-to-end verification) executed in a fresh
   session; give yourself a pass/fail check and show the evidence; after two failed
   corrections on one issue, `/clear` rather than correct a third time.
8. **Restore the debugging rule** (3-5 ranked falsifiable hypotheses before
   instrumenting; question the architecture after three failed fixes). It is one line,
   the measurement does not contradict it, and dropping a useful rule needs a positive
   reason.

Unchanged: all ADR-0006 hooks and their semantics, the git-mutation bans, single-logical-
change commits, `/ship` as the only committing skill, and the Codex projection's content.

## Consequences

- `bats tests/` is 114/114 green. Two parity tests that mutated `CLAUDE.md` to exercise
  the renderer's stale-source and marker validation now mutate
  `codex/workflow-contract.md`, since that is the source they were always testing.
- The Codex global projection changed by +8/-2 lines (the three principle anchors) to 32,344 B,
  4,520 B under the ceiling. Codex behavior should be unchanged apart from the anchors.
- `render-codex-agents.sh` still fails `CONTRACT_HOOK_REGISTRATION_INVALID` in the live
  working tree. This is the pre-existing Orca hook-reinjection condition, not a
  regression; the suite sanitizes it via `tests/helpers/orca-sanitize.bash`, and the
  projections here were rendered from a sanitized mirror.
- Request Lock is prompt-level and can rot like anything else. Its harness pairing is
  partial: `tests/named-override.bats` protects the override's referents, but nothing
  enforces the lock itself. Logged as a hook-enforcement candidate.
- The manual Codex behavioral-parity scenarios (TESTING.md 1-6) have **not** been re-run;
  structural checks only. Run them before the next parity claim.

## Kill criterion

Re-run `scratchpad/drift.py` / `drift2.py` two weeks from 2026-07-30 over sessions dated
after this ADR. The REDIRECT+REMOVE share of course-corrections is currently **79%**, and
post-code corrections **71%**.

- If REDIRECT+REMOVE does not fall below ~60%, the cause is not prompt-level. Stop
  editing prose and look at the skills' own generated preambles or at moving the check
  into a Stop hook.
- If it falls but post-code share stays at 71%, that is expected and fine — the goal was
  never to catch drift before a result exists, it was to make drift cheap. Judge that by
  how much was built before the correction, not by when it arrived.
- If Codex behavior degrades, the split is the suspect: `codex/workflow-contract.md` is
  byte-identical to v0.54.0 CLAUDE.md apart from the anchors, so a regression means the
  anchors, not the split.

## Rollback

`codex/workflow-contract.md` is v0.54.0's CLAUDE.md verbatim below its start marker.
Restoring the old behavior is: copy it back over `CLAUDE.md` (dropping the Codex-only
header comment), revert the source path in `codex/parity-contract.json` and
`render-codex-agents.sh`, drop the three anchors in `rules/operating-principles.md`,
delete `tests/named-override.bats`, and retarget the two parity tests at `CLAUDE.md`.
The hook layer is untouched by this ADR and needs no rollback.
