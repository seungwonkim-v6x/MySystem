# MySystem — Personal Workflow

This file defines the **complete workflow** that applies to all projects.

**CRITICAL RULE: The agent has ZERO discretion to skip steps.**
Every step below is MANDATORY and runs in order. The agent NEVER decides on its own
that a step "isn't needed" or "can be skipped for this case."
Only the USER can skip a step — by explicitly saying "skip [step]".

---

## Complete Workflow

### Feature / Bug Fix / Refactoring

Every code task goes through ALL 7 steps, in order:

```
1. /office-hours         ← validate the idea or problem
       ↓
2. /slow-down            ← concretize: problem, done criteria, scope, pre-mortem, approach
       ↓
3. /autoplan             ← full plan review: CEO + Design + Eng
       ↓
4. Implementation        ← write code (project-specific: lint, test, etc.)
       ↓
5. /review               ← PR code review: security, SQL safety, structure
       ↓
6. /bugbot               ← fresh-eye bug review of the diff
       ↓
7. /ship                 ← commit, push, create PR
```

### Debugging

```
1. /investigate          ← root cause analysis (no guessing, no fixing without cause)
       ↓
2. /slow-down            ← concretize the fix
       ↓
3. /autoplan             ← plan the fix
       ↓
4. Implementation → /review → /bugbot → /ship
```

### Weekly Retrospective

```
/retro                   ← commit history analysis, team contributions, trends
```

---

## Step Details

### Step 1: `/office-hours`

Run /office-hours. Present the output to the user. Wait for approval before proceeding.
User may say "skip office-hours" to skip.

### Step 2: `/slow-down`

Run /slow-down. Present the 5-step concretization to the user. Wait for approval before proceeding.
User may say "skip slow-down" to skip.

### Step 3: `/autoplan`

Enter Plan Mode. Run /autoplan which executes sequentially:
1. /plan-ceo-review — scope, ambition, strategy
2. /plan-design-review — UI/UX scoring 0-10
3. /plan-eng-review — architecture, edge cases, performance

Present the plan to the user. Wait for approval before proceeding.
User may say "skip autoplan" or "skip plan" to skip.

### Step 4: Implementation

Write code. Project-specific CLAUDE.md defines lint, test, and other checks here.

### Step 5: `/review`

Run /review to analyze the diff for security, SQL safety, trust boundary violations, structural problems.
Present findings to the user before proceeding.

### Step 6: `/bugbot`

Run /bugbot — fresh-eye subagent review of the diff.
Clean → proceed. Critical found → fix first, re-run.
User may say "skip bugbot" to skip.

### Step 7: `/ship`

Run /ship to commit, push, create PR.
Or use project-specific shipping workflow.

### `/investigate`

Run /investigate when the user reports a bug, error, or unexpected behavior.
Iron Law: no fixes without root cause.
4 phases: investigate → analyze → hypothesize → implement.

### `/retro`

Run /retro for weekly retrospective.
Analyzes commit history, work patterns, code quality metrics.

---

## Repo Self-Management Rules

When modifying this repository (MySystem), the agent MUST:

1. **Bump VERSION** — follow semver (major: breaking workflow change, minor: new skill/step, patch: fix/tweak)
2. **Update CHANGELOG.md** — add entry under new version with date and description
3. **Git tag** — create `vX.Y.Z` tag matching the VERSION file
4. **Sync ~/.claude/CLAUDE.md** — copy the updated CLAUDE.md to `~/.claude/CLAUDE.md` so it takes effect globally
5. **Sync skill files** — copy updated skills to `~/.claude/skills/` so they take effect globally
