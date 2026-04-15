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
After presenting results, STOP and wait. Do not say "proceeding to next step".
The user must explicitly say "ok", "approved", "next", "go" or similar before you move on.

---

## Execution Model

The coordinator (you) executes each workflow step by **invoking the corresponding skill directly**.
You follow the skill methodology, interact with the user, and use all available tools.
No custom subagents — gstack skills handle their own orchestration (e.g., /autoplan runs CEO + Design + Eng review internally).

---

## Complete Workflow

### Feature / Bug Fix / Refactoring

```
1. /office-hours         ← validate the idea or problem
       ↓  (wait for user approval)
2. /slow-down            ← concretize: problem, done criteria, scope, pre-mortem, approach
       ↓  (wait for user approval)
3. /research             ← search docs, codebase, existing solutions
       ↓  (wait for user approval)
4. /autoplan             ← write plan + CEO/Design/Eng review
       ↓  (wait for user approval)
5. Implementation        ← write code (coordinator directly)
       ↓  (wait for user approval)
6. Verification          ← ask user which verification to run (see below)
       ↓  (wait for user approval)
7. /review               ← PR code review: security, SQL safety, structure
       ↓  (wait for user approval)
8. /bugbot               ← fresh-eye bug review of the diff
       ↓  (wait for user approval)
9. /ship                 ← commit, push, create PR
```

### Debugging

```
1. /investigate          ← root cause analysis
       ↓  (wait for user approval)
2. /slow-down            ← concretize the fix
       ↓  (wait for user approval)
3. /research             ← search docs, similar issues, existing patterns
       ↓  (wait for user approval)
4. /autoplan             ← plan the fix + CEO/Design/Eng review
       ↓  (wait for user approval)
5. Implementation → /verify-test → /review → /bugbot → /ship
```

### Weekly Retrospective

```
/retro                   ← commit history analysis, team contributions, trends
```

---

## Step 6: Verification — Ask User

After implementation, present these options:

> 어떤 검증을 실행할까요?
>
> **A) 둘 다** — /verify-test (코드 테스트) + /qa-only (브라우저 QA)
> **B) /verify-test만** — throwaway 코드 테스트
> **C) /qa-only만** — 브라우저로 실제 플로우 검증
> **D) 건너뛰기** — 검증 없이 /review로 진행

Wait for user choice, then execute accordingly.

---

## /autoplan Details

Invoke the `/autoplan` skill directly. It handles the full pipeline:
1. Plan writing (EnterPlanMode → ExitPlanMode)
2. CEO/Design/Eng review (gstack manages the orchestration internally)
3. Present results and wait for user approval

---

## Context Management

- **Compact at 50%**: Run `/compact` when context usage reaches ~50%. Don't wait for automatic compaction.
- **Rewind when off-track**: Use Esc Esc (`/rewind`) instead of trying to fix a derailed conversation.
- **Clear for fresh start**: Use `/clear` when the context is too polluted to recover.

---

<important if="modifying the MySystem repository (~/.claude/) itself">
## Repo Self-Management Rules

When modifying this repository (MySystem), the agent MUST:

1. **Bump VERSION** — follow semver (major: breaking workflow change, minor: new skill/step, patch: fix/tweak)
2. **Update CHANGELOG.md** — add entry under new version with date and description
3. **Git tag** — create `vX.Y.Z` tag matching the VERSION file
4. **Sync skill files** — skill files are managed as **symlinks**, never copied. Use `ln -s` to link.
5. **Push to origin** — push commits and tags
</important>
