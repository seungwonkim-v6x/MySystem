# ADR-0015: Remove the gated workflow; keep hardened safety hooks

Date: 2026-07-13
Status: Superseded by ADR-0016 (2026-07-21)
Supersedes: the mandatory-pipeline aspect of ADR-0001; amends ADR-0006 (hard-refuse tier is now unconditional). ADR-0012 (/ai-review-loop) survives as a user-invoked tool; its auto-chain after /ship is removed.

> **Superseded (2026-07-21):** ADR-0016 restores the gated workflow; the gate
> removal below no longer describes the live system. The hook hardening this
> ADR shipped survives. This ADR's ADR-0012 amendment (auto-chain removed) is
> also reversed — the /ship→/ai-review-loop auto-chain is live again.

## Context

The 9-step mandatory workflow with STOP-and-wait approval gates was designed for
pre-Fable models. Deep research (2026-07-13) found every load-bearing source
pointing the same direction:

- Official Fable 5 prompting guidance: "Skills developed for prior models are
  often too prescriptive for Claude Fable 5 and can degrade output quality."
  Checkpoint guidance is one sentence — pause only for destructive/irreversible
  actions, real scope changes, or user-only input.
- Anthropic telemetry: ~93% of permission prompts are approved; per-action
  human gates decay into rubber-stamping. (Caveat, from our own review: that
  stat measures permission prompts, not workflow step gates — but our own
  logged pain, the workflow-weight feedback, points the same way.)
- Official CLAUDE.md guidance: files over ~200 lines reduce adherence. Ours
  was ~200 lines twice over (global + project), plus 123 lines of rules.
- Community consensus: the only rails minimalists keep are (a) hook-enforced
  destructive-action/secret/git blocks and (b) verification-before-completion
  evidence. Everything between is scope-conditional.
- In-repo evidence: the v0.44.0 prune deleted 7 of 9 sparse skills after zero
  invocations in ~99 sessions — discovered by transcript sampling alone, with
  no instrumentation.

A full /autoplan review (CEO/Eng/DX, dual Claude+Codex voices) first produced a
middle design: two-tier triage backed by a deterministic `tier-guard` PreToolUse
hook (state file, size budget, sensitive-path list, declaration CLI). It was
implemented and its 17 bats contracts passed. The user then invoked the
stronger alternative the review itself had surfaced (0C-bis D, "full
deletion"): remove all process gates, not just shrink them.

## Decision

1. **No mandatory workflow.** The 9-step pipeline, the step→skill mapping as
   an obligation, the successor map, per-step approval gates, the Step-5
   verification menu, the skill whitelist / mandatory-invocation rule, and the
   /ship→/ai-review-loop auto-chain are all removed. Skills remain installed
   as on-demand tools; the agent picks by task weight and names its pick.
2. **The human gate is the PR merge.** It needs no prose: merging is
   structurally a human action. Agents pause mid-task only per the
   one-sentence rule (destructive/irreversible, scope change, user-only input).
3. **Safety moves fully into code, and gets harder:**
   - The git hook's hard-refuse tier (force-push to main/master, and now
     `git commit --no-verify`/`-n` and `git reset --hard` on main/master)
     exits 2 **unconditionally** (the private-key hard refuse stays in
     secret-scanner.py with its existing semantics) — the `MYSYSTEM_HOOKS_ENFORCE` gate no longer
     applies to it. This fixes a latent constitution/code mismatch: prose
     claimed "always non-zero" while the code dry-ran by default.
   - Hard tier fails **closed** on unparseable payloads (jq → python3
     fallback → loud exit 2 naming the environment cause).
   - Rules are anchored to command-start positions after commit-message,
     heredoc-body, and quote-character normalization: mention-only text can
     never false-positive (the 2am self-injury class), while quoted arguments,
     newline separation, `VAR=x` prefixes, and `sh -c` wrappers cannot dodge
     a rule (adversarial suite in tests/hooks.bats).
   - Enforced blocks are logged to `~/.claude/logs/hook-blocks.log` so real
     friction (the rail-abandonment early signal) is measurable.
   - `~/.claude/logs/` is whitelisted in dangerous-command-blocker (hooks
     write telemetry there by design).
   - Soft tier keeps the ADR-0006 dry-run default; Auto Mode's classifier
     remains the live adjudicator for ambient command risk.
4. **CLAUDE.md becomes a ~55-line working agreement** (judgment defaults,
   safety pointers, skills-as-tools, repo mode, knowledge locations), keeping
   the Codex parity markers (`claude-workflow`, `core-skills`,
   `conditional-skills`) so the ADR-0014 projection keeps rendering.

## Alternatives considered

- **Tiered triage with deterministic tier-guard** (built, then removed in this
  same branch — the code lives in this branch's history for cheap revival).
  Rejected because it relocates gates into hooks rather than removing them:
  ~7 new concepts (tiers, budgets, declaration CLI, TTL, enrollment) for an
  operator whose complaint was harness weight, violating trigger-driven
  shipping — it ships permanent machinery to test whether misclassification
  is even a real problem, when transcript sampling (v0.44.0 precedent) can
  answer that with zero machinery.
- **Prose-only softening** (keep pipeline, calm the register). Rejected:
  keeps advisory-only safety and the >200-line adherence problem.
- **Wholesale MYSYSTEM_HOOKS_ENFORCE=1 + sandbox.** Rejected: over-blocking
  causes rail abandonment; sandboxing is a separate future lake (TODOS).

## Coverage delta accepted

Pre-merge review is no longer mandatory (neither /review nor
/requesting-code-review). This repo has no SQL or production surface; its
artifacts are hooks and docs, now covered by bats contracts and CI. On repos
that DO have such surfaces (e.g. vProp), invoke the review skills — this ADR
removes obligations, not tools. Historical note: on one past branch both
review passes caught distinct real fixes (7e466e3, 44ba346); that loss is
accepted consciously, watched by the kill criterion below.

## What is durable vs Fable-5-contingent

- [durable] Safety in hooks, not prose; evidence before completion claims;
  PR merge as the human gate; commit scoping.
- [Fable-5-contingent] Trusting the model to self-select planning/review/
  verification depth; the calm (non-MUST) register. Revisit on the next model
  generation, or if Claude Code ships native task-triage/gating (which would
  retire this ADR's judgment-defaults prose entirely).

## Kill criterion / quality watch

/retro samples transcripts + `hook-blocks.log`. Two to three real incidents of
the same failure class (post-ship fix commits on unreviewed work, skipped
verification claims, hook false positives) = the trigger to re-add ONE
targeted rail (a review requirement, a check, or the archived tier-guard) —
never the whole pipeline. Review by 2026-09-01 or ~30 tasks, whichever first.

## Rollback

`git revert` the v0.49.0 commits, run `./setup.sh` (re-renders projections),
and the previous gated CLAUDE.md is live again. The hook hardening
(unconditional hard tier, fail-closed parsing, bypass-resistant matching) is
independent of the gate removal and should survive any rollback.
