# MySystem — Personal Workflow

This file defines the **complete workflow** that applies to all projects.

**CRITICAL RULE: The agent has ZERO discretion to skip or reorder steps.**
Every step below is MANDATORY and runs in order.
- NEVER skip a step on your own.
- NEVER reorder steps. Step N must complete before step N+1 begins.
- NEVER write code before /slow-down and /autoplan are done. NOT EVEN ONE LINE.
- NEVER ask the user "should we skip?" or "do you want to run the full workflow?"
- NEVER suggest skipping. Just run the next step immediately.
- If the user wants to skip, THEY will interrupt you. That's their job, not yours.

---

## Ensemble Execution Rule

**Every workflow step** (except Implementation and /ship) MUST be executed as an ensemble:

1. Spawn **3-5** subagents, each with a **paraphrased variation** of the same task
   - Same goal and context, but vary the phrasing, emphasis, or angle
   - e.g., one asks "find bugs", another "what could break in production", another "trace edge cases"
   - Variation increases diversity of findings beyond LLM non-determinism alone
2. Each subagent has fresh context — no shared state between them
3. After all complete, the coordinator synthesizes:
   - Deduplicate overlapping findings
   - Merge unique findings from each agent
   - Rank by severity/importance
4. Present **one unified report** to the user

The underlying skill (gstack or custom) is a black box.
MySystem controls **how many times** it runs, not how it runs internally.

Why: LLM non-determinism means each run finds different things. Running N times
gives broader coverage than running once. This is the core leverage of the system.

Why: LLM non-determinism means each run finds different things. Running N times
gives broader coverage than running once. This is the core leverage of the system.

---

## Complete Workflow

### Feature / Bug Fix / Refactoring

Every code task goes through ALL 9 steps, in order:

```
1. /office-hours         ← validate the idea or problem (ensemble)
       ↓
2. /slow-down            ← concretize: problem, done criteria, scope, pre-mortem, approach (ensemble)
       ↓
3. /research             ← search docs, codebase, existing solutions (ensemble)
       ↓
4. /autoplan             ← full plan review: CEO + Design + Eng (ensemble)
       ↓
5. Implementation        ← write code (project-specific: lint, test, etc.)
       ↓
6. /verify-test          ← generate throwaway tests, run, delete (ensemble)
       ↓
7. /review               ← PR code review: security, SQL safety, structure (ensemble)
       ↓
8. /bugbot               ← fresh-eye bug review of the diff (ensemble)
       ↓
9. /ship                 ← commit, push, create PR
```

### Debugging

```
1. /investigate          ← root cause analysis (ensemble)
       ↓
2. /slow-down            ← concretize the fix (ensemble)
       ↓
3. /research             ← search docs, similar issues, existing patterns (ensemble)
       ↓
4. /autoplan             ← plan the fix (ensemble)
       ↓
5. Implementation → /verify-test → /review → /bugbot → /ship
```

### Weekly Retrospective

```
/retro                   ← commit history analysis, team contributions, trends (ensemble)
```

---

## Step Details

### Step 1: `/office-hours`

Run /office-hours. Present the output to the user. Wait for approval before proceeding.
User may say "skip office-hours" to skip.

### Step 2: `/slow-down`

Run /slow-down. Present the 5-step concretization to the user. Wait for approval before proceeding.
User may say "skip slow-down" to skip.

### Step 3: `/research`

Run /search-first and /documentation-lookup to gather context before planning:
- Search for existing solutions (npm, PyPI, MCP, GitHub)
- Fetch up-to-date documentation for relevant libraries via Context7
- Analyze the codebase for existing patterns that solve the problem

Present findings to the user. Wait for approval before proceeding.
User may say "skip research" to skip.

### Step 4: `/autoplan`

After research is complete, IMMEDIATELY run /autoplan. Do not ask. Do not skip.
Even if the user already accepted a plan via ExitPlanMode, /autoplan still runs.
Plan acceptance ≠ plan review. They are separate steps.

Run /autoplan which executes sequentially:
1. /plan-ceo-review — scope, ambition, strategy
2. /plan-design-review — UI/UX scoring 0-10
3. /plan-eng-review — architecture, edge cases, performance

Present the review results to the user. Wait for approval before proceeding.
User may say "skip autoplan" or "skip plan" to skip.

### Step 5: Implementation

Write code. Project-specific CLAUDE.md defines lint, test, and other checks here.

### Step 6: `/verify-test`

Run /verify-test to generate throwaway code-based tests:
- Analyze the diff to determine what was changed
- Generate test files in /tmp (never in the project)
- Run tests using the project's framework
- Report results
- Delete all test files

If tests fail, fix the implementation and re-run. Do not fix the tests.

### Step 7: `/review`

Run /review to analyze the diff for security, SQL safety, trust boundary violations, structural problems.
Present findings to the user before proceeding.

### Step 8: `/bugbot`

Run /bugbot — fresh-eye subagent review of the diff.
Clean → proceed. Critical found → fix first, re-run.
User may say "skip bugbot" to skip.

### Step 9: `/ship`

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

## Subagent Permission Rules

Subagents spawned by ensemble execution use read-only permissions by default:

```yaml
tools: Read, Grep, Glob, Bash
permissionMode: dontAsk
```

Only the **main coordinator agent** may:
- Edit or Write files
- Run git commit, push, reset, or any git write operations
- Create PRs or interact with external services

Subagents for /verify-test get extended permissions (Write to /tmp only):
```yaml
tools: Read, Grep, Glob, Bash, Write
permissionMode: dontAsk
# Write restricted to /tmp/ via PreToolUse hook
```

---

## Repo Self-Management Rules

When modifying this repository (MySystem), the agent MUST:

1. **Bump VERSION** — follow semver (major: breaking workflow change, minor: new skill/step, patch: fix/tweak)
2. **Update CHANGELOG.md** — add entry under new version with date and description
3. **Git tag** — create `vX.Y.Z` tag matching the VERSION file
4. **Sync ~/.claude/CLAUDE.md** — copy the updated CLAUDE.md to `~/.claude/CLAUDE.md` so it takes effect globally
5. **Sync skill files** — copy updated skills to `~/.claude/skills/` so they take effect globally
