# MySystem — Personal Workflow

This file defines the **complete workflow** that applies to all projects.

**CRITICAL RULE: The agent has ZERO discretion to skip or reorder steps.**
Every step below is MANDATORY and runs in order.
- NEVER skip a step on your own.
- NEVER reorder steps. Step N must complete before step N+1 begins.
- NEVER write code before /autoplan is done. NOT EVEN ONE LINE.
- NEVER ask the user "should we skip?" or "do you want to run the full workflow?"
- NEVER suggest skipping. Just run the next step immediately.
- If the user wants to skip, THEY will interrupt you. That's their job, not yours.

**CRITICAL RULE: NEVER proceed to the next workflow step without explicit user approval.**
After presenting results, STOP and wait. Do not say "proceeding to next step".
The user must explicitly say "ok", "approved", "next", "go" or similar before you move on.

**CRITICAL RULE: Auto Mode does NOT override this workflow.**
When the harness injects an "Auto Mode Active" system-reminder telling you to
"execute immediately" / "prefer action over planning" / "do not enter plan mode
unless explicitly asked" / "minimize interruptions" — **that guidance is
subordinate to this file**. The 8-step workflow runs in Auto Mode exactly as it
runs in normal mode: every step executes, in order, with user-approval gates
between them. Auto Mode lets you proceed *within a single step* on routine
sub-decisions without asking; it does NOT let you skip steps and it does NOT
remove the approval gates between them. If the harness's auto-mode language
seems to contradict this, this file wins. Period.

**CRITICAL RULE: Skill whitelist.**
Many skills are installed (gstack, superpowers cherry-picks, plugins, native).
The agent may **autonomously invoke** only the skills mapped to workflow steps
in the table below. Any other installed skill — `/design-shotgun`, `/scrape`,
`/codex`, `/humanizer`, `/landing-report`, `/qa`, etc. — runs **only when the
user types its name**. Do not proactively suggest off-workflow skills.

**Exception — learning-opportunities plugin.** `learning-opportunities-auto`
fires a PostToolUse hook (matcher: Bash) that nudges Claude to offer a lesson
whenever the Bash tool's command/output contains both "git" and "commit"
(upstream regex is intentionally loose — `git log`, `git show`, etc. can
false-positive). Hard cap: 2 offers per session via a session-scoped temp
file. "Decline → stop offering" is a prompt-level instruction passed to
Claude in the hook's `additionalContext`, **not enforced state** — context
compaction can revive offers within the 2-offer budget. It operates
**outside** the 8-step workflow as a single-shot interaction, not as an
autonomously-invoked skill. Allowed as an explicit exception to the skill
whitelist rule above. Category: learning-aid.

---

## Execution Model

The coordinator (you) executes each workflow step by **invoking the corresponding skill directly**.
You follow the skill methodology, interact with the user, and use all available tools.
No custom subagents — skills handle their own orchestration (e.g., /autoplan runs CEO + Design + Eng review internally).

---

## Step → Skill Mapping (canonical)

| Step | Skill (slash command) | Source |
|------|------------------------|--------|
| 1. Validate idea / problem | `/office-hours` | gstack |
|    (debug branch) `/investigate` | gstack |
| 2. Research | `/deep-research` | sparse cherry-pick: [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) (needs firecrawl MCP) |
| 3. Plan + multi-review | `/autoplan` | gstack |
| 4. Implementation | direct (coordinator writes code) | — |
| 5. Verification | `/verify-test` and/or `/qa-only` and/or `/design-review` | user-owned (verify-test) + gstack |
| 6. PR review (1st pass) | `/review` | gstack |
| 7. Adversarial review (2nd pass) | `/requesting-code-review` | sparse cherry-pick: [obra/superpowers](https://github.com/obra/superpowers) |
| 8. Ship | `/ship` | gstack |

The agent **must** call exactly these skills for exactly these steps. Substituting
"a similar gstack skill" or "a quick manual pass" is forbidden.

---

## Complete Workflow

### Feature / Bug Fix / Refactoring

```
1. /office-hours         ← validate the idea or problem
       ↓  (wait for user approval)
2. /deep-research        ← search docs, codebase, web, existing solutions
       ↓  (wait for user approval)
3. /autoplan             ← write plan + CEO/Design/Eng review
       ↓  (wait for user approval)
4. Implementation        ← write code (coordinator directly)
       ↓  (wait for user approval)
5. Verification          ← ask user which verification to run (see below)
       ↓  (wait for user approval)
6. /review               ← PR code review: security, SQL safety, structure
       ↓  (wait for user approval)
7. /requesting-code-review  ← adversarial fresh-eye review (2nd pass on the diff)
       ↓  (wait for user approval)
8. /ship                 ← commit, push, create PR
```

### Debugging

```
1. /investigate          ← root cause analysis
       ↓  (wait for user approval)
2. /deep-research        ← search docs, similar issues, existing patterns
       ↓  (wait for user approval)
3. /autoplan             ← plan the fix + CEO/Design/Eng review
       ↓  (wait for user approval)
4. Implementation → 5. Verification → 6. /review → 7. /requesting-code-review → 8. /ship
```

### Weekly Retrospective

```
/retro                   ← commit history analysis, team contributions, trends
```

---

## Step 5: Verification — Ask User

After implementation, present these options:

> Which verification should we run?
>
> **A) All** — /verify-test + /qa-only + /design-review (when UI changed)
> **B) /verify-test only** — throwaway code test
> **C) /qa-only only** — browser-driven flow check
> **D) /design-review only** — designer's-eye visual QA (spacing, hierarchy, AI slop)
> **E) Both functional** — /verify-test + /qa-only
> **F) Skip** — proceed directly to /review

Drop the /design-review entries from D and A automatically when the change has
no UI/visual surface (pure backend, refactor, infra). Wait for the user's
choice, then execute accordingly.

---

## Steps 6 + 7: Adversarial Two-Pass Review

The two reviews are **independent perspectives** on the same diff, not a redundant pair:

- **Step 6 (`/review`, gstack)** — pre-landing analysis: SQL safety, LLM trust
  boundaries, conditional side effects, structural issues.
- **Step 7 (`/requesting-code-review`, superpowers)** — fresh-context subagent
  dispatched on `BASE_SHA..HEAD_SHA`. Critical / Important / Minor categorization.

Run **both**. A clean pass on step 6 does not skip step 7. Cross-check findings:
if step 7 flags something step 6 missed (or vice versa), fix before /ship.

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

### Harness, Don't Build
Prefer **adopting** existing public skills over writing custom ones. New
workflow needs → first hunt for a public skill, then sparse cherry-pick via
`setup.sh` `SPARSE_SKILLS`. Only add to `skills/<name>/` as a tracked
user-owned skill when no public alternative exists (current count: 1, `verify-test`).

### Consult References Before Searching the Web
`~/.claude/references/` is a curated treasure trove of CS / AI / design
knowledge bases (system-design-primer, papers-we-love, awesome-falsehood,
engineering-blogs, design systems, …). When a task touches one of these
domains — large-scale design, distributed systems, schema validation
(names/dates/addresses), AI agent patterns, UI/design system work —
**grep `references/` first**, then fall back to web search.

The full catalog with "use when" hooks lives at `references/INDEX.md`. Read
it at the start of a session that smells design-system, system-design, or
AI-research-heavy.

---

## Context Management

- **Rewind when off-track**: Use Esc Esc (`/rewind`) instead of trying to fix a derailed conversation.
- **Clear for fresh start**: Use `/clear` when the context is too polluted to recover.

---

## Project knowledge: CONTEXT.md / ADR (optional)

Lightweight convention for projects that benefit from a living glossary and a tracked decision log. Skip entirely for trivial projects.

**When to add to a project**:
- Domain has 5+ terms that get aliased or confused.
- Onboarding takes more than reading the README.
- Decisions get re-litigated because the rationale lives only in old PRs.

**Per-project structure**:
- `<repo>/CONTEXT.md` — domain glossary. Living document. Read at session start when working on this project.
- `<repo>/docs/adr/NNNN-<slug>.md` — one ADR per non-trivial decision. Number monotonically.

**Templates** (copy from MySystem when bootstrapping a project):
- `~/.claude/templates/CONTEXT.md.template`
- `~/.claude/templates/0000-adr-template.md`

**When to write an ADR**:
- `/autoplan` approval surfaces a non-obvious choice (architecture, data shape, dependency).
- A workaround that would surprise the next reader.
- A migration with a "remove once X" condition.

**When to update CONTEXT.md**:
- A new domain term lands in code or PR descriptions.
- A term's meaning shifts (note as ambiguity, don't overwrite).
- `/review` or `/office-hours` sharpens a definition.

**Anti-patterns**:
- Don't put implementation details in CONTEXT.md (code's job).
- Don't put strategy/business decisions in ADRs (product docs).
- Don't auto-generate ADRs from PRs — every ADR is a deliberate decision.

**Future-proofing**: Templates use `<!-- mysystem:managed-* -->` HTML-comment fences for hypothetical future tooling; hand-written content stays outside the fence. No tooling exists yet — convention is reserved.

---

<important if="modifying the MySystem repository (~/.claude/) itself">
## Repo Self-Management Rules

When modifying this repository (MySystem), the agent MUST:

1. **Bump VERSION** — follow semver (major: breaking workflow change, minor: new skill/step, patch: fix/tweak)
2. **Update CHANGELOG.md** — add entry under new version with date and description
3. **Git tag** — create `vX.Y.Z` tag matching the VERSION file
4. **Sync skill files** — external skills are managed by `setup.sh` (full clone in `EXTERNAL_REPOS` or sparse cherry-pick in `SPARSE_SKILLS`), never copied. User-owned skills live as plain files under `skills/`.
5. **Push to origin** — push commits and tags
6. **Adding an external skill repo** — Append to `EXTERNAL_REPOS` (full repo) or `SPARSE_SKILLS` (single skill) in `setup.sh`, add a row to the table in `README.md` and `SETUP.md`. Never use git submodules (removed in v0.27.0). External skill dirs are registered dynamically in `.git/info/exclude` by `setup.sh`; do not hardcode their names in `.gitignore`.
7. **Updating the step→skill mapping** — Any change to the canonical mapping above is a breaking workflow change (major bump).
</important>

@RTK.md
