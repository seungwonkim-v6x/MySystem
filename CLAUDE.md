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

1. Spawn **3** Claude subagents (model: **sonnet**), each with a **paraphrased variation** of the same task
   - Same goal and context, but vary the phrasing, emphasis, or angle
   - e.g., one asks "find bugs", another "what could break in production", another "trace edge cases"
   - Variation increases diversity of findings beyond LLM non-determinism alone
   - Use `model: "sonnet"` when spawning via Agent tool — saves cost, Opus stays as coordinator only
2. Run **Codex CLI** in parallel as a cross-model voice:
   - For review/analysis: `codex review --base <base-branch>` or `codex exec "<task>" -s read-only`
   - For implementation: `codex exec "<task>" -s workspace-write` (produces version B alongside Claude's version A)
   - Codex findings are included in the unified report as a "Cross-Model (Codex)" section
3. Run **Gemini CLI** in parallel as a cross-model voice:
   - For review/analysis: `gemini -p "<task>" --approval-mode plan -o text`
   - Gemini is always read-only — NEVER use `--yolo` or `--approval-mode auto_edit` in ensemble steps
   - For long diffs: write diff to a tmp file and pipe via stdin: `cat /tmp/diff.txt | gemini -p "<task>" --approval-mode plan -o text`
   - Gemini findings are included in the unified report as a "Cross-Model (Gemini)" section
4. Each subagent and CLI has fresh context — no shared state between them
5. If Codex or Gemini CLI fails (auth expired, timeout, not found), **continue with available results** — Claude ensemble alone is sufficient
6. After all complete, the coordinator synthesizes:
   - Deduplicate overlapping findings from Claude ensemble
   - Merge Codex and Gemini findings — flag cross-model disagreements prominently
   - Rank by severity/importance
7. Present **one unified report** to the user

**Total: 5 perspectives** — 3 Claude sonnet subagents + Codex + Gemini.
This is the core leverage of the system: model diversity catches what any single model misses.

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

Each step runs as an ensemble (3 Claude subagents + Codex + Gemini). The skill file provides the methodology.

| Step | Skill file to read | What to extract |
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
