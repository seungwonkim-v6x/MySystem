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

**Every workflow step** (except /ship) MUST be executed via the `/scion-ensemble` skill.
No exceptions. No "I'll just do it myself." Invoke the skill FIRST, THEN act on the results.

1. Invoke `/scion-ensemble` with the step name and task description
2. The skill spawns a **4-agent ensemble** in parallel:
   - 1 local Claude (Agent tool, sonnet) — has full project context, gstack skills, uncommitted changes
   - 3 Scion containers: Claude Opus + Gemini 2.5 Pro + Codex — isolated, fresh perspective, own git worktrees
3. Each agent independently executes the task
4. Results are collected, deduplicated, and categorized:
   - **Consensus**: findings 2+ agents agree on (high confidence)
   - **Unique catches**: findings only 1 agent caught (tagged by model)
   - **Disagreements**: agents contradict each other (user decides)
5. Present unified report to the user

**Fallback**: If Scion is unavailable (Docker not running, no credentials), the skill
degrades to local-only Agent tool ensemble (3 sonnet subagents) and warns the user.

Why: Different models catch different failure modes. 4 agents across 3 vendors
gives genuine epistemic diversity, not just LLM non-determinism within one model.

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

### How every step works (except /ship)

**MANDATORY for EVERY step below:**
1. Read the relevant gstack skill file from `~/.claude/skills/<skill-name>/SKILL.md`
2. Extract the key methodology (phases, evaluation criteria, output format)
3. Invoke /scion-ensemble with a prompt that includes: user's task + extracted methodology + structured output format
4. All 4 agents (1 local + 3 Scion) get the SAME prompt with the methodology inlined
5. Collect results, synthesize, present unified report
6. Wait for user approval before proceeding to the next step

DO NOT run the skill directly. DO NOT skip the ensemble. The skill file is a methodology source, not something you invoke — you extract its methodology and feed it to /scion-ensemble.

### Step 1: `/office-hours`

Read `~/.claude/skills/office-hours/SKILL.md`. Extract the methodology.
Invoke /scion-ensemble with the methodology + user's idea/problem. Present unified report. Wait for approval.

### Step 2: `/slow-down`

Read `~/.claude/skills/slow-down/SKILL.md`. Extract the 5-step concretization process.
Invoke /scion-ensemble. Present unified report. Wait for approval.

### Step 3: `/research`

Read `~/.claude/skills/search-first/SKILL.md` and `~/.claude/skills/documentation-lookup/SKILL.md`.
Invoke /scion-ensemble with research methodology. Present unified report. Wait for approval.

### Step 4: `/autoplan`

Read `~/.claude/skills/autoplan/SKILL.md`. Extract the CEO + Design + Eng review methodology.
Invoke /scion-ensemble. Present unified report. Wait for approval.

### Step 5: Implementation

Invoke /scion-ensemble with implementation task. Coordinator synthesizes the best approach and writes code.
Project-specific CLAUDE.md defines lint, test, and other checks.

### Step 6: `/verify-test`

Read `~/.claude/skills/verify-test/SKILL.md`. Extract the test generation methodology.
Invoke /scion-ensemble. If tests fail, fix and re-run.

### Step 7: `/review`

Read `~/.claude/skills/review/SKILL.md`. Extract review criteria.
Invoke /scion-ensemble with diff + review methodology. Present findings. Wait for approval.

### Step 8: `/bugbot`

Read `~/.claude/skills/bugbot/SKILL.md`. Extract fresh-eye bug review methodology.
Invoke /scion-ensemble with diff + methodology. Clean → proceed. Critical → fix first.

### Step 9: `/ship`

Run /ship directly. This is the ONLY step that does NOT use /scion-ensemble.

### `/investigate`

Read `~/.claude/skills/investigate/SKILL.md`. Extract 4-phase methodology.
Invoke /scion-ensemble with bug description + methodology. Iron Law: no fixes without root cause.

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
