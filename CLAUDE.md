# MySystem — Personal Workflow Gates

This file defines **mandatory gates** that apply to all projects.
Project-specific workflows integrate these gates in their own CLAUDE.md.

---

## Gate 1: Slow Down — Pre-Coding Concretization

**Trigger**: User requests code implementation, bug fix, or refactoring
**Action**: Run `/slow-down` skill (5-step concretization)
**Done when**: User approves the concretization output

```
IF user requests code work
AND none of these exceptions apply:
  - "just do it", "skip slow-down", "skip concretization"
  - Trivially obvious change (typo, one-liner, simple rename)
  - Ticket already has detailed design (Description contains implementation plan)
  - Request is a question, explanation, or research task
THEN run /slow-down → proceed only after user approval
```

## Gate 2: Plan Review — Design Verification for Non-Trivial Work

**Trigger**: Slow-down output shows blast radius of 3+ files, or includes architecture changes
**Action**: Enter Plan Mode, run `/autoplan` or individual reviews
**Done when**: User approves the plan

```
IF work is non-trivial (3+ files affected, new module, API change, DB schema change)
THEN EnterPlanMode → /autoplan (or /plan-ceo-review, /plan-eng-review, /plan-design-review individually)
     → proceed only after user approval
ELSE proceed directly to implementation
```

## Gate 3: Bugbot — Pre-Commit Bug Review

**Trigger**: About to run git commit or push
**Action**: Run `/bugbot`
**Done when**: Clean = commit proceeds. Critical found = fix first, re-run.

```
IF about to git commit or push
AND none of these exceptions apply:
  - "skip bugbot", "just commit"
THEN run /bugbot → clean = commit, critical = fix first
```

---

## Workflow Summary

All code work follows this sequence. Each project's CLAUDE.md adds project-specific steps.

```
Request received
  ↓
[Gate 1] /slow-down        ← concretize (mandatory)
  ↓
[Gate 2] /autoplan         ← design review (non-trivial work only)
  ↓
Implementation + tests     ← project-specific (lint, test, etc.)
  ↓
[Gate 3] /bugbot           ← pre-commit review (mandatory)
  ↓
Commit / PR / Deploy       ← /ship or project-specific workflow
```

### Debugging
```
Bug report / error → /investigate (root cause required, no guessing)
```

### Weekly Retrospective
```
End of week/sprint → /retro (commit analysis, team contributions)
```

---

## Skill Inventory

### Owned (MySystem)
| Skill | Role |
|---|---|
| slow-down | Gate 1: Pre-coding concretization |
| bugbot | Gate 3: Pre-commit bug review |

### Dependent (gstack — auto-updated)
| Skill | Role |
|---|---|
| office-hours | Idea validation (optional, before Gate 1) |
| autoplan | Gate 2: CEO + Design + Eng review pipeline |
| plan-ceo-review | Gate 2 individual: scope/ambition check |
| plan-eng-review | Gate 2 individual: architecture/edge cases |
| plan-design-review | Gate 2 individual: UI/UX scoring |
| review | PR code review (security/structure) |
| investigate | Debugging: root cause analysis |
| retro | Weekly retrospective |
| ship | Commit → PR workflow |
