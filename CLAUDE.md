# MySystem — Personal Workflow

This file defines the **complete workflow** that applies to all projects.
Every skill listed here MUST be used at its designated step.
Project-specific workflows in each project's CLAUDE.md add project-specific details (lint commands, test commands, Jira integration, etc.) but do NOT skip any step defined here.

---

## Complete Workflow

### Feature / Bug Fix / Refactoring

```
1. /office-hours         ← validate the idea or problem (when problem is ambiguous or new)
       ↓
2. /slow-down            ← concretize: problem, done criteria, scope, pre-mortem, approach (MANDATORY)
       ↓
3. /autoplan             ← full plan review (when non-trivial: 3+ files, new module, API/DB change)
   ├─ /plan-ceo-review      scope, ambition, strategy
   ├─ /plan-design-review   UI/UX scoring 0-10
   └─ /plan-eng-review      architecture, edge cases, performance
       ↓
4. Implementation        ← write code (project-specific: lint, test, etc.)
       ↓
5. /review               ← PR code review: security, SQL safety, structure (BEFORE commit)
       ↓
6. /bugbot               ← fresh-eye bug review of the diff (MANDATORY, BEFORE commit)
       ↓
7. /ship                 ← commit, push, create PR
```

### Debugging

```
1. /investigate          ← root cause analysis (no guessing, no fixing without cause)
       ↓
2. /slow-down            ← concretize the fix (if non-trivial)
       ↓
3. Implementation → /review → /bugbot → /ship
```

### Weekly Retrospective

```
/retro                   ← commit history analysis, team contributions, trends
```

---

## Step Details

### Step 1: `/office-hours` — Idea Validation

```
IF the problem is ambiguous, or it's a new feature idea, or the user is unsure what to build
THEN run /office-hours to validate demand, specificity, and approach
ELSE skip to step 2
```

### Step 2: `/slow-down` — Pre-Coding Concretization (MANDATORY)

```
IF user requests code work
AND none of these exceptions apply:
  - "just do it", "skip slow-down", "skip concretization"
  - Trivially obvious change (typo, one-liner, simple rename)
  - Ticket already has detailed design (Description contains implementation plan)
  - Request is a question, explanation, or research task
THEN run /slow-down → 5-step concretization → proceed only after user approval
```

### Step 3: `/autoplan` — Plan Review (Non-Trivial Work)

```
IF work is non-trivial (3+ files affected, new module, API change, DB schema change)
THEN EnterPlanMode → /autoplan
     /autoplan runs sequentially: /plan-ceo-review → /plan-design-review → /plan-eng-review
     → proceed only after user approval
ELSE skip to step 4
```

Individual reviews can be invoked directly when only one perspective is needed:
- `/plan-ceo-review` — challenge scope and ambition
- `/plan-design-review` — rate UI/UX dimensions 0-10
- `/plan-eng-review` — lock architecture, edge cases, test coverage

### Step 4: Implementation

Write code. Project-specific CLAUDE.md defines lint, test, and other checks here.

### Step 5: `/review` — PR Code Review

```
IF code changes are ready for commit
THEN run /review to analyze the diff for:
     - SQL safety issues
     - LLM trust boundary violations
     - Conditional side effects
     - Structural problems
```

### Step 6: `/bugbot` — Pre-Commit Bug Review (MANDATORY)

```
IF about to git commit or push
AND none of these exceptions apply:
  - "skip bugbot", "just commit"
THEN run /bugbot → fresh-eye subagent review
     Clean → proceed to commit
     Critical found → fix first, re-run /bugbot
```

### Step 7: `/ship` — Commit and PR

```
THEN run /ship to: commit, push, create PR
OR use project-specific shipping workflow
```

### `/investigate` — Debugging

```
IF user reports a bug, error, or unexpected behavior
THEN run /investigate
     Iron Law: no fixes without root cause
     4 phases: investigate → analyze → hypothesize → implement
```

### `/retro` — Weekly Retrospective

```
IF end of week or sprint
THEN run /retro
     Analyzes commit history, work patterns, code quality metrics
     Team-aware: per-person breakdowns with praise and growth areas
```

---

## Repo Self-Management Rules

When modifying this repository (MySystem), the agent MUST:

1. **Bump VERSION** — follow semver (major: breaking workflow change, minor: new skill/step, patch: fix/tweak)
2. **Update CHANGELOG.md** — add entry under new version with date and description
3. **Git tag** — create `vX.Y.Z` tag matching the VERSION file
4. **Sync ~/.claude/CLAUDE.md** — copy the updated CLAUDE.md to `~/.claude/CLAUDE.md` so it takes effect globally
5. **Sync skill files** — copy updated skills to `~/.claude/skills/` so they take effect globally
