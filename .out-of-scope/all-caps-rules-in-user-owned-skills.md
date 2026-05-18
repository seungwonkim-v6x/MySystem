# Out of Scope: ALL-CAPS Rules in User-Owned Skills

**Decision date:** 2026-05-18 (v0.36.0)
**Source for the rejected guidance:** [anthropics/skills/skill-creator/SKILL.md](https://github.com/anthropics/skills/tree/main/skills/skill-creator)
**Status:** Rejected for the workflow contract; accepted for user-owned skill bodies.

## What was considered

Anthropic's official `skill-creator` skill is the authoritative guide on
SKILL.md authoring. It explicitly warns against ALL-CAPS prohibitions:

> Don't force rigid structures — if you find yourself writing ALWAYS or
> NEVER in all caps or building oppressively constrictive rules, step back
> and reframe by explaining the underlying reasoning instead.

The rationale: LLMs respond better to reasoning than rote rules; oppressive
constraints push the model into corner-case rationalization. The
generalize-don't-overfit principle.

## Why it was attractive

This is first-party Anthropic guidance from the team that knows the model
best. The principle holds in general — most skill bodies and most agent
prompts genuinely do better with reasoned explanation than with shouting.

## Why we rejected it (for the workflow contract specifically)

MySystem's CLAUDE.md is not a skill body; it's the **workflow contract**.
The CRITICAL RULE / NEVER / ZERO DISCRETION framing exists because:

1. **The 8-step workflow has a documented failure mode**: the agent
   reasoning its way around the rule ("this question seems too simple for
   /office-hours"). Reasoned rules ("you should usually invoke
   /office-hours unless...") leave the loophole open. ALL-CAPS closes it.
2. **Auto Mode pressure**: the harness can inject reminders like "execute
   immediately, prefer action over planning." Reasoned rules lose to
   imperative harness signals. ALL-CAPS rules win.
3. **The user is the only consumer of MySystem**. Anthropic's guidance
   optimizes for the typical skill author who wants their skill to apply
   broadly to many users; MySystem's audience is one person who has
   deliberately chosen the strict mode and tested that it works.

The Instruction Precedence ladder in CLAUDE.md (added v0.36.0) formalizes
this: workflow-contract rules are level 3-4 (product/dev instructions +
agent role); harness reminders are level 1-3; reasoned skill-body guidance
is level 4-5. The CRITICAL RULE framing matches the level.

## Where Anthropic's guidance DOES apply in MySystem

**User-owned skills under `skills/`** (currently only `verify-test/`,
plus any future additions): follow Anthropic's authoring rules **with one
documented exception class** (below). Reasoned explanations beat ALL-CAPS
for behavioral guidance; pushy descriptions beat passive ones; body under
500 lines.

### Documented exception: data-hygiene rules

`skills/verify-test/SKILL.md` contains two ALL-CAPS rules
("**ALWAYS delete test files after reporting**" and "test files are NEVER
staged, committed, or kept"). These are deliberate exceptions because the
failure mode (repo pollution by leftover throwaway tests) is a one-way
door — once a test file is committed it has to be unwound. Reasoned
guidance ("you should probably delete...") would let the model rationalize
keeping a "useful-looking" test, which is exactly the failure mode the
skill exists to prevent.

The category: **data-hygiene rules where the failure mode is irreversible
side-effect on the repo or filesystem**. ALL-CAPS is permitted for this
class. Behavioral rules ("when X happens, do Y") in user-owned skills
should still follow Anthropic's reasoned-prose convention.

This `.out-of-scope/` entry exists so a future contributor who reads
`anthropics/skills/skill-creator/SKILL.md` and notices the contradiction
finds the deliberate rationale here instead of re-deriving it.

## What would make us reconsider

- A documented case where the ALL-CAPS framing in CLAUDE.md misfired
  (model rationalized around it, model failed to follow it on a borderline
  case, model treated it as adversarial constraint).
- Anthropic publishes specific guidance on workflow-contract authoring
  (different from skill authoring) that addresses this distinction.
- MySystem grows from solo to team usage (the audience-of-one assumption
  changes).

## Related

- [docs/adr/0006-defense-in-depth-pretooluse-hooks.md](../docs/adr/0006-defense-in-depth-pretooluse-hooks.md) — harness-not-model principle that motivates moving rules from prompt to enforcement when possible.
- CLAUDE.md "Harness, Not Model" section — when a CRITICAL RULE should aspire to be a hook instead.
