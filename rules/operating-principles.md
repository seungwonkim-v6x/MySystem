<!-- mysystem:section operating-principles:start -->
# Operating Principles

Always-loaded principles that shape how MySystem work gets done. Loaded by Claude Code's native `.claude/rules/` mechanism (no `paths:` frontmatter = applies to all sessions).

## Boil the Lake (Completeness)

AI makes the marginal cost of completeness near-zero. When you present options, prefer the **complete implementation** (all edge cases, full coverage, proper error paths) over the "80% shortcut". The delta between 80 lines and 150 lines is meaningless with Claude+gstack. Don't skip the last 10% to "save time" — that 10% costs seconds.

Flag "oceans" (rewrites of systems you don't control, multi-quarter migrations) as out of scope. Boil lakes, not oceans.

## Harness, Not Model

**Every CRITICAL RULE in CLAUDE.md should aspire to a paired harness enforcement.** Prompt-only rules silently rot under context pressure; harness-level rules don't. When a new prompt-only rule is added, log it as a hook-enforcement candidate by adding a line to the active `CHANGELOG.md` entry under a `### Hook-enforcement candidates` heading, with the rule name + one sentence about which hook event could enforce it. Sweep that heading during the next patch release planning to decide which candidates to promote.

The model proposes actions; the harness validates, authorizes, executes, records, and returns observations. The v0.35.0 defense-in-depth hooks (secret-scanner, dangerous-command-blocker, env-file-protection, block-dangerous-git) are an example — though they run dry-run by default (detect + log, not block; `MYSYSTEM_HOOKS_ENFORCE` is intentionally unset since Auto Mode's permission gate is the live risk adjudicator), with only the hard-refuse tiers blocking unconditionally. **Prefer native Claude Code features over custom workarounds** — if Anthropic ships `.claude/rules/`, use it; do not invent a parallel system.

**Resolved candidate — inline decision narration (v0.47.0, negative result).** A proposed always-on rule ("announce non-obvious implementation decisions inline as you make them, so the user catches a bad one before it compounds") was investigated and **held, not shipped**. Research (Anthropic docs) confirmed no hook event fires on a model's judgment — `MessageDisplay` is display-only — so it is *irreducibly prompt-level*, the exact class this principle warns rots under context pressure. It also lacked a real trigger (it would ship permanent config to test whether the problem is even real — violates trigger-driven shipping). Re-open only after 2-3 real instances of a silent Step-4 decision causing rework are logged; if built, pair it with a `/retro` transcript-sampling audit (the closest thing to enforcement available) and a default-to-delete kill date. This is a documented negative result, not a TODO.

## Repeated Multi-Step Prompts Are Missing Skills

If a multi-step prompt repeats across sessions, that's a missing skill, not a habit. Promote it via `setup.sh` `SPARSE_SKILLS` (or as a user-owned skill in `skills/` if no public alternative exists) before re-typing it a third time. Three is the trip-wire: once is novel, twice is coincidence, three times is a pattern that deserves codification.

The failure mode this closes: hand-walking the agent through the same verification dance ("run X, then check Y, then write Z to disk") every week because nobody promoted it. Hand-walking is acceptable while discovering the shape; it becomes tech debt once the shape is stable.

## Vertical-Slice TDD Only (Never Horizontal)

When tests accompany an implementation, write them as vertical slices — one test → one implementation → repeat — not horizontal batches. Batch-written tests verify the *shape* of code rather than its *behavior*; they pass against any implementation that matches the imagined interface but miss the real edge cases.

Specifically forbidden:
- Writing all tests for a module first, then all implementation
- "Stub out 20 test files describing the expected API, then fill them in"
- Generating a test plan with N test cases and implementing all of them before any production code exists

Required pattern: Pick one behavior → write one failing test → write minimal production code to pass → refactor → next behavior. Auto Mode + the "boil the lake" instinct can push toward batch test writing during Step 4; this rule overrides that pressure.

## Conditional Clarification (Inside a Step)

Inside a single workflow step, ask only when critical information is missing AND cannot be reasonably inferred. Hard ceiling: 3 clarifying questions per step. Beyond that, make the reasonable call and document the assumption in the design doc, plan, or output (the user can correct).

This rule complements (does not replace) cross-step approval gates AND the mandatory-skill-invocation rule. Approval gates between steps stay strict; this reduces within-step interruption when context is clear enough. **It does NOT authorize asking "should I invoke skill X?"** — that question is forbidden by the mandatory-invocation rule; you invoke and let the user interrupt. The 3-question budget covers clarifications within an already-invoked skill, not skill-selection deliberation.

Force questions only on: Outcome (what success looks like), Audience (who the artifact is for), Format (what kind of artifact), Hard constraints (deadlines, blocked tech, budget). If all four are inferrable from prior turns, the design doc, or sensible defaults, do not ask.

## Repo Mode — Solo vs Collaborative

Behavior adapts to who owns issues:
- **Solo** (MySystem, cc-guard, personal projects) — One person does 80%+ of the work. Notice issues outside the current branch's changes (test failures, deprecation warnings, dead code, env problems) → investigate and offer to fix proactively. Default to action.
- **Collaborative** (vProp, team repos) — Multiple active contributors. Notice issues outside the branch's changes → flag in one sentence — it may be someone else's responsibility. Default to asking, not fixing.
- **Unknown** — Treat as collaborative (safer default).

**See Something, Say Something**: whenever you notice something that looks wrong during ANY workflow step, flag it in one sentence. Never let a noticed issue silently pass.

## Harness, Don't Build

Prefer adopting existing public skills over writing custom ones. New workflow needs → first hunt for a public skill, then sparse cherry-pick via `setup.sh` `SPARSE_SKILLS`. Only add to `skills/<name>/` as a tracked user-owned skill when no public alternative exists.
<!-- mysystem:section operating-principles:end -->
