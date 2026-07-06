# ADR-0013: Step 4 design discipline — native frontend-design + machine-checkable rider; narration held

- **Status**: Accepted
- **Date**: 2026-07-07
- **Author**: seungwon-v6x
- **Tags**: workflow, step-4, design, taste-skill

<!-- mysystem:managed-start (intentionally empty — reserved for future tooling) -->
<!-- mysystem:managed-end -->

## Context

AI-generated UI reads as generic slop; the user self-identifies as having no design ability, so
Claude's opinionated taste is the real pain (memory: user-design-dependency). Starting point was
"vendor `Leonxlnx/taste-skill` into Step 4." Office-hours re-scoped the concept twice: first to a
*generation-time* guardrail (not post-hoc QA), then — at the user's steer — to a *domain-agnostic*
idea: surface the AI's silent mid-implementation decisions (naming, data shape, library, UI default)
before the user reverse-engineers them later. taste-skill turned out to be just the UI instance of it.

Deep-research established three load-bearing facts: (1) native `/frontend-design` (Anthropic plugin,
already installed) already delivers the opinionated-taste layer and does NOT read a `DESIGN.md`;
(2) taste-skill is MIT, cleanly extractable; (3) the "announce decisions inline" pattern has no
off-the-shelf implementation and is **not hook-enforceable** — no hook event fires on a model's
judgment (`MessageDisplay` is display-only), so it is irreducibly prompt-level.

/autoplan's four-voice review (Codex + CEO/Eng/DX subagents) then converged that the narration half
had no real trigger and would ship permanent, unenforceable, always-on config to test whether the
problem is even real — violating the repo's own trigger-driven-shipping and Harness-Not-Model rules.

## Decision

We wire **two explicitly-loaded layers** into Step 4 on a *material UI change* (new UI or reshaping,
not any UI file touched): `/frontend-design` for taste, and a per-project `DESIGN.md` **rider**
(`~/.claude/templates/DESIGN.md`) for *machine-checkable bans only* (h-screen, emoji-icons, flex-math,
spinner, missing states) plus named design presets (calm/balanced/bold). Both load explicitly because
frontend-design will not pick up the rider. **Precedence: frontend-design wins on taste; rider bans are
hard.** We do NOT vendor taste-skill; we extract its stack-agnostic subset.

The domain-agnostic **inline-decision-narration rule is HELD**, not built. It re-opens only after 2-3
real instances of a silent Step-4 decision causing rework are logged, and if built must pair with a
`/retro` transcript-sampling audit and a default-to-delete kill date. Boundary: this ADR does not add
any hook, output-style, binary, or vendored third-party skill.

## Alternatives considered

- **A: Vendor taste-skill's SKILL.md into Step 4** — rejected: ~80% overlaps native frontend-design, adds supply-chain + SHA-pin maintenance, and its stack guards are React/Next-specific.
- **B: Native frontend-design only, no rider** — rejected: loses the objective machine-checkable bans that judgment-only prose does not enforce.
- **C: Ship the narration rule now as an always-on `.claude/rules/*.md`** — rejected: no trigger/baseline, unenforceable, permanent context-budget cost; four-model consensus said hold.
- **D: Path-scope the narration rule to code files** — rejected: decisions are domain-agnostic (config/schema/prompt/test too) and path-scoped rules fire on Read, not Write (miss new-file creation).

## Consequences

- ✓ Step 4 gains a taste layer (native, zero-maintenance) + objective bans, with defined precedence.
- ✓ No vendored third-party skill, no hook, no binary — pure prompt-level config; trivial rollback.
- ✗ The rider is a hand-copied snapshot of taste-skill's bans — it can drift; refresh manually if taste-skill's ban list materially changes.
- ✗ frontend-design is materiality-gated by the agent's judgment ("material UI change") — a soft trigger, not enforced.
- ? Whether the silent-decision problem is real enough to justify the narration rule later — we are deliberately waiting for evidence instead of guessing.

## References

- Related ADR: ADR-0009 (claude-md-trim-and-native-rules), ADR-0011 (deep-research-vendored)
- Design doc: `~/.gstack/projects/seungwonkim-v6x-MySystem/2026-07-06-design-taste-skill-step4.md`
- Research: `~/.gstack/projects/seungwonkim-v6x-MySystem/2026-07-06-research-decision-surfacing.md`
- Code: `~/.claude/templates/DESIGN.md`, `~/.claude/CLAUDE.md` (Step 4 — design discipline), `~/.claude/rules/operating-principles.md` (Harness, Not Model)
- Upstream: `github.com/Leonxlnx/taste-skill` (MIT); Anthropic frontend-design plugin

## How this file is maintained

Hand-written ADR. Supersede with a new ADR if the narration rule is later built or the rider approach changes.
