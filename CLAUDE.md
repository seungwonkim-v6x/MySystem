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
> **A) 전부** — /verify-test + /qa-only + /design-review (UI 변경 시)
> **B) /verify-test만** — throwaway 코드 테스트
> **C) /qa-only만** — 브라우저로 실제 플로우 검증
> **D) /design-review만** — 디자이너 관점 시각 QA (spacing, hierarchy, AI slop)
> **E) 둘 다(기능)** — /verify-test + /qa-only
> **F) 건너뛰기** — 검증 없이 /review로 진행

UI/시각 변경이 없는 작업(순수 백엔드/리팩터링 등)에는 D·A의 /design-review를 자동 제외.
Wait for user choice, then execute accordingly.

---

## /autoplan Details

Invoke the `/autoplan` skill directly. It handles the full pipeline:
1. Plan writing (EnterPlanMode → ExitPlanMode)
2. CEO/Design/Eng review (gstack manages the orchestration internally)
3. Present results and wait for user approval

---

## Operating Principles

### Boil the Lake (Completeness Principle)
AI-assisted coding makes the marginal cost of completeness near-zero. When you present options, always prefer the **complete implementation** (all edge cases, full coverage, proper error paths) over the "80% shortcut". The delta between 80 lines and 150 lines is meaningless with Claude+gstack. Don't skip the last 10% to "save time" — with AI, that 10% costs seconds.

Flag "oceans" (rewrites of systems you don't control, multi-quarter migrations) as out of scope. Boil the lakes.

### Repo Mode — Solo vs Collaborative
Behavior adapts to who owns issues in the current repo:

- **Solo** (cc-guard, personal projects, MySystem itself) — One person does 80%+ of the work. When you notice issues outside the current branch's changes (test failures, deprecation warnings, dead code, env problems), **investigate and offer to fix proactively**. Default to action.
- **Collaborative** (vProp, team repos) — Multiple active contributors. When you notice issues outside the branch's changes, **flag them briefly via one sentence** — it may be someone else's responsibility. Default to asking, not fixing.
- **Unknown** — Treat as collaborative (safer default).

**See Something, Say Something**: whenever you notice something that looks wrong during ANY workflow step, flag it in one sentence. Never let a noticed issue silently pass.

---

## Context Management

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
6. **Adding an external skill repo** — Append to `EXTERNAL_REPOS` in `setup.sh`, add a row to the table in `README.md` and `SETUP.md`. Never use git submodules (removed in v7.4.0). Skill dirs installed by the external repo are registered dynamically in `.git/info/exclude` by `setup.sh`; do not hardcode their names in `.gitignore`.
</important>

@RTK.md
