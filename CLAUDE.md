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

**CRITICAL RULE: NEVER proceed to the next workflow step without explicit user approval.**
After presenting ensemble results, STOP and wait. Do not say "proceeding to next step".
The user must explicitly say "ok", "approved", "next", "go" or similar before you move on.

---

## Ensemble Execution Rule

**Every workflow step** (except Implementation and /ship) MUST be executed as an ensemble:

### Subagent Execution Model

Subagents are NOT summarizers. Each subagent **reads the skill file itself and runs the full methodology internally**.

The coordinator's job is to:
1. Tell each subagent what task to perform and which skill to follow
2. Provide full task context (never truncated, never summarized to 300 chars)
3. Wait for ALL to complete
4. Synthesize the combined results

The coordinator does NOT:
- Extract methodology from SKILL.md and paste it into a short prompt
- Summarize or truncate the task description
- Move on after only 1-2 agents respond

### Execution Steps

1. **Spawn 3 Claude subagents** (model: **opus**) in a **single message** (all 3 as parallel Agent tool calls)
   - Each subagent prompt MUST include:
     - The full task description with all relevant context
     - The instruction: "Read `~/.claude/skills/<skill>/SKILL.md` and follow its methodology completely"
     - A varied angle/perspective to increase diversity of findings
   - Subagent prompts must be detailed and complete — never fewer than several sentences

2. **WAIT FOR ALL** — NEVER synthesize or present results until every subagent has returned
   - Do NOT proceed after 1 or 2 agents return. Wait for ALL 3 subagents.
   - All 3 Claude subagents are non-negotiable. No partial results.

3. **Synthesize** — after ALL 3 agents return:
   - Deduplicate overlapping findings
   - Flag disagreements prominently
   - Rank by severity/importance
   - Present **one unified report** to the user

4. **STOP** — present the report and **wait for explicit user approval** before the next workflow step.

**Total: 3 perspectives** — 3 Claude opus subagents, each running the full skill methodology independently.

### Subagent Prompt Template

Each subagent prompt should follow this pattern:

```
You are performing /<skill-name> for this task.

TASK: <full task description — all context the coordinator has>

INSTRUCTIONS:
- Read the skill file at ~/.claude/skills/<skill>/SKILL.md
- Follow its methodology completely
- Provide your full analysis — do not summarize or truncate
- <varied angle: e.g., "Focus on edge cases" or "Focus on security implications" or "Challenge assumptions">
```

---

## Complete Workflow

### Feature / Bug Fix / Refactoring

Every code task goes through ALL 9 steps, in order:

```
1. /office-hours         ← validate the idea or problem (ensemble)
       ↓  (wait for user approval)
2. /slow-down            ← concretize: problem, done criteria, scope, pre-mortem, approach (ensemble)
       ↓  (wait for user approval)
3. /research             ← search docs, codebase, existing solutions (ensemble)
       ↓  (wait for user approval)
4. /autoplan             ← full plan review: CEO + Design + Eng (ensemble)
       ↓  (wait for user approval)
5. Implementation        ← write code (project-specific: lint, test, etc.)
       ↓  (wait for user approval)
6. /verify-test          ← generate throwaway tests, run, delete (ensemble)
       ↓  (wait for user approval)
7. /review               ← PR code review: security, SQL safety, structure (ensemble)
       ↓  (wait for user approval)
8. /bugbot               ← fresh-eye bug review of the diff (ensemble)
       ↓  (wait for user approval)
9. /ship                 ← commit, push, create PR
```

### Debugging

```
1. /investigate          ← root cause analysis (ensemble)
       ↓  (wait for user approval)
2. /slow-down            ← concretize the fix (ensemble)
       ↓  (wait for user approval)
3. /research             ← search docs, similar issues, existing patterns (ensemble)
       ↓  (wait for user approval)
4. /autoplan             ← plan the fix (ensemble)
       ↓  (wait for user approval)
5. Implementation → /verify-test → /review → /bugbot → /ship
```

### Weekly Retrospective

```
/retro                   ← commit history analysis, team contributions, trends (ensemble)
```

---

## Step Details

Each step: coordinator spawns subagents → subagents read SKILL.md and run full methodology → coordinator waits for ALL → synthesizes → presents → waits for user approval.

| Step | Skill file (subagents read this internally) | What to extract |
|------|--------------------|-----------------|
| /investigate | `~/.claude/skills/investigate/SKILL.md` | 4-phase root cause methodology |
| /office-hours | `~/.claude/skills/office-hours/SKILL.md` | Idea validation methodology |
| /slow-down | `~/.claude/skills/slow-down/SKILL.md` | 5-step concretization process |
| /research | `~/.claude/skills/search-first/SKILL.md` | Research-before-coding workflow |
| /autoplan | `~/.claude/skills/autoplan/SKILL.md` | CEO + Design + Eng review |
| Implementation | (no skill file) | Implementation task description |
| /verify-test | `~/.claude/skills/verify-test/SKILL.md` | Throwaway test generation |
| /review | `~/.claude/skills/review/SKILL.md` | Code review criteria |
| /bugbot | `~/.claude/skills/bugbot/SKILL.md` | Fresh-eye bug review |
| /ship | Run directly — without ensemble | |

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
4. **Sync skill files** — skill files are managed as **symlinks**, never copied. Use `ln -s` to link.
5. **Push to origin** — push commits and tags
