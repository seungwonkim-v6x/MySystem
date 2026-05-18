# ADR-0007: Skill cherry-pick batch v0.37.0 + ADR-0005 SHA-pin amendment

**Status:** Accepted (2026-05-18)
**Context window:** v0.37.0 release
**Amends:** ADR-0005 (Plugin marketplace mechanism — supply-chain trust)
**Related:** ADR-0002 (SPARSE_SKILLS install mechanism)

## Context

The v0.36.0 best-practices research catalog
(`~/.gstack/projects/seungwonkim-v6x-MySystem/best-practices-research-20260518.md`)
identified 8 external skills filling concrete gaps in MySystem's workflow
that aren't covered by gstack, the existing obra/superpowers cherry-pick,
the existing affaan-m cherry-pick, or the 6 marketplace plugins
(frontend-design, context7, code-review, learning-opportunities,
learning-opportunities-auto, orient).

The first /autoplan pass surfaced a supply-chain concern from /requesting-code-review's
CEO #1: going from 3 to 11 SPARSE_SKILLS entries, with 4 of them
load-bearing for the workflow (autonomous invocation), all unpinned by
default per ADR-0005, means upstream rename or compromise silently breaks
or compromises the workflow. ADR-0005's "unpinned by design" was justified
for a 3-skill surface; at 11 skills with autonomy split, the math changes.

## Decision

### 1. Add 8 SPARSE_SKILLS entries

**obra/superpowers (2 additions):**
- `verification-before-completion` — Iron Law skill: "no completion claims
  without fresh verification evidence." **Autonomous (Step 5 augment).**
- `test-driven-development` — Iron Law skill: "no production code without
  a failing test first." **User-invoked only** (opt-in Step 4 modifier).

**mattpocock/skills (6 additions):**
- `diagnose` — feedback-loop-first debugging with ranked falsifiable
  hypotheses. **Autonomous** (alternate to `/investigate` in Debug Step 1).
- `grill-with-docs` — interview against CONTEXT.md glossary + ADRs.
  **Autonomous** (optional pre-Step-3).
- `prototype` — throwaway runnable code answering one question.
  **User-invoked only.**
- `triage` — state-machine for issues + AI-generated comment disclaimer.
  **User-invoked only** (collaborative repos).
- `zoom-out` — single-shot "give me a map using project glossary."
  **User-invoked only.**
- `handoff` — cross-agent continuation doc (distinct from `/context-save`).
  **Autonomous** (auto-suggested after `/context-save` for cross-agent
  delegation).

### 2. SHA pinning for autonomous skills (amends ADR-0005)

ADR-0005 ("Plugin marketplace mechanism") established `unpinned-by-design`
for SPARSE_SKILLS picks. v0.37.0 amends this for **autonomous skills only**:

- **Autonomous skills (workflow-whitelisted, agent-invoked)** MUST be
  pinned to a commit SHA.
- **User-invoked skills** MAY remain unpinned per the original ADR-0005
  convention.

Rationale: autonomous skills are invoked silently by the agent. A compromised
or even just well-intentioned-but-breaking upstream commit becomes live
agent behavior on the next `./setup.sh`. User-invoked skills require the
user to type the slash command, which means the user has at least the
chance to notice the skill's content changed if it surprises them. The
trust gradient maps to the invocation mode.

This is the smallest possible relaxation of ADR-0005: it pins 4 out of 11
SPARSE_SKILLS entries (the 4 autonomous v0.37.0 adds). The 2 pre-existing
unpinned entries (requesting-code-review, deep-research) are left unpinned
for backward compatibility; their content has been stable, and the next
upstream-drift incident would prompt a follow-up pin.

### 3. Implementation

**setup.sh format extension:**
- Old: `"skill-name|url|branch|subpath"` (4 fields)
- New: `"skill-name|url|branch|subpath[|commit-SHA]"` (5 fields, optional 5th)

When the 5th field is present, `setup.sh` runs `git checkout <SHA>` after
clone instead of tracking branch tip. If the SHA is unreachable (upstream
rewrote history), setup.sh exits 1 with a clear remediation message.

**Initial SHAs (captured at vendor time, 2026-05-18 via gh api):**
- obra/superpowers main HEAD: `f2cbfbefebbf`
- mattpocock/skills main HEAD: `e74f0061bb67`

**Refresh process:**
1. Manually inspect upstream changes since the pinned SHA:
   `cd external-skills/<skill-name> && git log <pinned-SHA>..origin/main`.
2. If the changes are wanted: update the pin in `setup.sh` SPARSE_SKILLS
   to the new SHA (12 hex chars).
3. **Re-read the skill's SKILL.md and confirm the CLAUDE.md description
   still matches.** If the skill's behavior, name, or trigger conditions
   changed in the new SHA, also update the matching entry in the CLAUDE.md
   "v0.37.0 skill additions — invocation policy" section. This is the
   only mechanism preventing skill-description drift (no auto-sync).
4. Record both the pin bump AND any CLAUDE.md description update in
   CHANGELOG with the upstream commit description.
5. No auto-update. Each pin bump is a deliberate decision.

**Drift detection (manual):** During a `/retro` session or quarterly
review, run for each pinned skill:
```bash
cd external-skills/<skill-name> && git log --oneline <pinned-SHA>..origin/main | head
```
If the output shows substantive changes (skill rewrite, new section,
removed feature), schedule a pin-refresh task.

### 4. CLAUDE.md whitelist policy

Added explicit autonomous-vs-user-invoked classification in CLAUDE.md
Step → Skill Mapping section. Lists which 4 of 8 new skills are added to
the autonomous whitelist (verification-before-completion, diagnose,
grill-with-docs, handoff) and which 4 are user-invoked only
(test-driven-development, prototype, triage, zoom-out).

### 5. references/INDEX.md additions

Two new entries under a "Skill authoring" section — NOT cloned into
`references/` (no behavior change to the reference repos catalog),
just citable docs the agent consults when writing user-owned skills:
- `anthropics/skills` SKILL.md authoring contract
- `wshobson/agents` sub-agent frontmatter convention

## Consequences

### Positive
+ 4 new autonomous skills fill real workflow gaps: Step 5 evidence
  enforcement, Debug Step 1 alternate, pre-Step-3 glossary interview,
  cross-agent handoff. All inputs the workflow previously relied on
  user-typed-skill ergonomics for.
+ 4 user-invoked skills available for opt-in: TDD discipline, prototype
  spike, issue triage, navigation aid. Discovered via /verify-test
  research; not pushed proactively.
+ SHA pinning materially reduces supply-chain risk on the 4 most-trusted
  picks. Compromised upstream → broken setup, not silent compromise.
+ ADR-0005 stays intact for user-invoked picks (unpinned ergonomics
  preserved where the user can review on invocation).

### Negative
- SPARSE_SKILLS array grows from 2 to 10 entries. Setup time on fresh
  install increases by ~5-15 seconds (each entry clones a separate repo).
  Acceptable; the alternative (one mega-repo with all skills) has worse
  diff-readability properties.
- Pin refresh becomes manual maintenance. The hooks ecosystem moves;
  pinning a Step 5 augment to a 6-month-old commit means missing 6
  months of upstream improvements. Trade-off accepted: review before
  refresh > silent absorption.
- Two separate refresh cadences (pinned vs unpinned) to track. Document
  in `setup.sh` comments + the SETUP.md SPARSE_SKILLS table.

## Alternatives considered

| Alternative | Reason rejected |
|---|---|
| Pin all 11 SPARSE_SKILLS | Over-broad — user-invoked skills don't need it, and unpinned ergonomics keep onboarding new picks low-friction |
| Vendor autonomous skills as tracked files in `skills/<name>/` | Same trust model as user-owned skills (data, not workflow code) but heavier maintenance: every upstream change requires manual port. Pinning gives 80% of the benefit with 10% of the cost |
| Keep autonomous unpinned, document trust in ADR | The whole point of /requesting-code-review CEO #1 was that documentation alone doesn't mitigate silent compromise. Pinning does |
| Skip the 4 user-invoked skills (only ship the 4 autonomous) | The user-invoked skills are zero-cost when not typed; the marginal install time is negligible. Ship the whole batch |
| Use git submodules instead of SHA pin | Removed in v0.27.0 due to maintenance friction. Not coming back |

## Refresh log (future)

When an autonomous skill's pin is bumped, add a line here:

| Date | Skill | Old SHA | New SHA | Upstream changes |
|------|-------|---------|---------|------------------|
| 2026-05-18 | verification-before-completion | (initial) | f2cbfbefebbf | Initial vendor |
| 2026-05-18 | diagnose | (initial) | e74f0061bb67 | Initial vendor |
| 2026-05-18 | grill-with-docs | (initial) | e74f0061bb67 | Initial vendor |
| 2026-05-18 | handoff | (initial) | e74f0061bb67 | Initial vendor |

## Related ADRs

- ADR-0002 — SPARSE_SKILLS install mechanism (the underlying convention)
- ADR-0005 — Plugin marketplace + supply-chain unpinned-by-design (now amended for autonomous SPARSE_SKILLS)
- ADR-0006 — Defense-in-depth via hand-vendored PreToolUse hooks (sibling supply-chain decision — hand-vendor for hooks, SHA-pin for autonomous skills)
