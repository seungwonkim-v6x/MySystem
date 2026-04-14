# Changelog

All notable changes to MySystem are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [6.0.0] - 2026-04-14

### Changed
- **Breaking**: Removed ensemble (3x subagent per step). Each step now calls 1x subagent directly.
- **Breaking**: Interactive vs Ralph difference reduced to approval only. Same workflow, same agents.
- **Breaking**: Ralph switched from screen + `claude -p` to Ralph Loop plugin (Stop Hook based).
- Simplified subagent invocation: call via `subagent_type` directly, coordinator must not re-interpret or re-inject skill content.
- Only /autoplan retains 3 subagents (role division: CEO + Design + Eng).
- Updated ralph-start and ralph-report skills to Ralph Loop plugin based.

### Removed
- Ensemble Execution Rule section entirely
- 3x parallel subagent execution pattern
- screen + ralph-autonomous.sh based autonomous execution

## [5.9.0] - 2026-04-14

### Added
- **Ralph Autonomous Mode**: Autonomous execution of MySystem workflow while user is away. Each iteration = 1 task x 1 workflow step. Steps 1~8 auto-execute, /ship always requires human.
- **`ralph-planner` agent** (`agents/ralph-planner.md`): Detailed implementation plan writer for autonomous execution
- **Ralph runtime** (`~/.claude/ralph/{project}/`): ralph-autonomous.sh (main loop), next-step.py (task/step selection), advance-step.py (step advancement, atomic write), safety-autonomous.md (safety rules)
- **CLAUDE.md**: Added Ralph Autonomous Mode section (Interactive vs Autonomous comparison, safety measures, file locations)
- **Available Custom Subagents table**: Added `ralph-planner`

### Design Decisions
- Runtime files stored outside repo (`~/.claude/ralph/`) to avoid git status pollution
- Reuses existing agents (`--agent` flag) — no separate methodology prompts needed
- Single agent per step (not ensemble) — 1/3 token cost, suitable for autonomous execution
- `--disallowed-tools` CLI hard block + `safety-autonomous.md` soft block dual safety

## [5.8.1] - 2026-04-10

### Added
- **Central mempalace wing configs** (`mempalace/wings/vprop/`): moved `mempalace.yaml` and `entities.json` out of project directories into MySystem so they don't pollute project git status/diff

## [5.8.0] - 2026-04-10

### Added
- **3 external skill submodules**: `code-review-skill` (React/TS/Vue review), `playwright-skill` (E2E tests), `superpowers` (systematic-debugging)
- **Submodule auto-update hook** (`submodule-auto-update.sh`): SessionStart fetches latest for all submodules in background, restores broken symlinks if updated
- **systematic-debugging** skill symlink from superpowers

### Changed
- `investigator` agent: added `systematic-debugging` skill (4-phase execution guardrails)
- `code-reviewer` agent: added `cso` (OWASP/STRIDE) + `code-review-skill` (React 19/TS review)
- `eng-reviewer` agent: added `health` (code quality dashboard)
- `test-verifier` agent: added `playwright-skill` (E2E test generation)

## [5.7.0] - 2026-04-10

### Added
- **setup.sh**: Clone-and-run bootstrap script — inits gstack submodule, restores broken skill symlinks, verifies all agent → skill mappings. Run `cd ~/.claude && ./setup.sh` on any new machine.

## [5.6.0] - 2026-04-10

### Added
- **MemPalace integration**: Replaced claude-mem with MemPalace for persistent memory (raw verbatim storage, 96.6% R@5 retrieval)
- **SessionStart hook** (`mempalace-wake-up.sh`): Injects MemPalace L0+L1 wake-up context (~170 tokens) at every session start
- **Stop hook** (`mempalace-auto-mine.sh`): Auto-mines session transcript into MemPalace on session end
- **MCP server** (`mempalace`): Registered as user-scope MCP for semantic search across all sessions

### Removed
- **claude-mem**: Plugin uninstalled, launchd workers/updater removed

### Changed
- Subagent models switched from opus to sonnet (cost reduction)

## [5.5.0] - 2026-04-09

### Added
- **3 new custom subagents**: `office-hours`, `slow-downer`, `test-verifier` — every ensemble step now has a dedicated subagent with preloaded skills
- **PreToolUse hook** (`require-subagent-type.sh`): Blocks Agent calls without `subagent_type`. Hard enforcement — coordinator cannot bypass by using generic Agent(model: "opus")

### Changed
- Step Details table: all steps now reference named subagents, no more "generic" entries
- All 10 subagents have `skills:` frontmatter for automatic SKILL.md preloading

## [5.4.2] - 2026-04-09

### Fixed
- **Enforce subagent_type usage**: Added CRITICAL rule + correct/wrong examples to prevent coordinator from ignoring custom subagents and spawning generic `Agent(model: "opus")` with inline prompts instead

## [5.4.1] - 2026-04-09

### Fixed
- **/autoplan two-phase flow**: Coordinator must write a plan via EnterPlanMode, get user approval via ExitPlanMode, THEN pass the full approved plan to CEO/Design/Eng reviewers. Previously coordinator was skipping the plan phase and writing its own inline summary directly into subagent prompts.

## [5.4.0] - 2026-04-09

### Changed
- **Correct subagent invocation**: Rewrite CLAUDE.md to use `Agent(subagent_type: "name")` pattern
- **Skills preloading**: Add `skills:` frontmatter to agent files — SKILL.md content is preloaded at session start, no runtime file reads needed
- **Agent frontmatter hardened**: Add `permissionMode: dontAsk`, `effort: high` to all agent definitions
- **Execution Steps / Step Details consistency**: Both now unified around `subagent_type` invocation

### Fixed
- Disconnect between Execution Steps (inline prompts) and Step Details (custom agent names) resolved
- Subagents no longer need to read SKILL.md at runtime — replaced with skills preloading

## [5.3.0] - 2026-04-09

### Added
- **Custom Subagents** (`~/.claude/agents/`): 7 dedicated subagent definitions created
  - `ceo-reviewer.md`, `design-reviewer.md`, `eng-reviewer.md` (role-based for /autoplan)
  - `code-reviewer.md`, `bug-hunter.md` (dedicated for /review and /bugbot)
  - `investigator.md`, `researcher.md` (dedicated for /investigate and /research)
- Each agent embeds its own model, tools, and instructions — no more passing long prompts at runtime

### Changed
- Step Details table: skill file references replaced with custom subagent references
- Subagent invocation: Agent tool + inline prompts replaced with pre-defined `.claude/agents/` files

## [5.2.0] - 2026-04-09

### Changed
- **/autoplan**: Same skill x3 replaced with role-based subagents (Agent 1=CEO, Agent 2=Design, Agent 3=Eng). Each subagent reads and executes its own role's SKILL.md.
- **Implementation**: Excluded from ensemble, coordinator runs directly (needs file write permissions)

## [5.1.0] - 2026-04-09

### Changed
- **Opus-only ensemble**: Subagent model changed from sonnet to opus. Codex CLI and Gemini CLI removed (unstable).
- **Subagents run skills internally**: Coordinator no longer extracts/summarizes methodology. Each subagent reads SKILL.md and runs the full methodology itself.
- **Fixed at 3 perspectives**: 3 opus subagents. Coordinator only synthesizes.

### Fixed
- Coordinator was proceeding after only 1 subagent returned — now waits for ALL 3
- Coordinator was advancing to next workflow step without user approval — now requires explicit approval after every step
- Subagent prompts were truncated to ~300 chars — now require full context + "read SKILL.md yourself" instruction

### Removed
- Codex CLI integration (unstable invocation)
- Gemini CLI integration (unstable invocation)

## [5.0.0] - 2026-04-09

### Changed
- **Base reverted to v3.3.0**: Rolled back Scion-based v4.x architecture. Step-detail table (v4.2.0) retained.
- **Ensemble fixed at 5 perspectives**: 3 Claude sonnet subagents + Codex CLI + Gemini CLI. Removed "3-5" variable range.
- **Codex CLI flags updated**: `--read-only` to `-s read-only`, `--write` to `-s workspace-write` (Codex v0.118.0)
- **Repo Self-Management**: Skill sync changed from copy to symlink

### Added
- **Gemini CLI v0.36.0**: Added as cross-model voice alongside Codex (`gemini -p "<prompt>" --approval-mode plan -o text`)
- **Graceful degradation**: Continue with Claude ensemble alone if Codex/Gemini CLI fails
- **Long diff handling**: tmp file + stdin pipe pattern documented

### Removed
- **Scion CLI dependency**: "THE ONE RULE" (mandatory scion-ensemble first call) removed
- **Docker/Scion container ensemble**: 4-agent Scion architecture fully removed
- **Per-step prose descriptions**: Replaced with step-detail table

### Fixed
- v4.x workflow failing every session due to Scion CLI not being installed
- Codex CLI v0.118.0 flag compatibility

## [4.2.0] - 2026-04-08

### Changed
- **Complete CLAUDE.md rewrite**: reduced from 190 lines to 70 lines. One rule at the top: "your first tool call is /scion-ensemble". Everything else supports that one rule.
- **"THE ONE RULE" pattern**: instead of 10+ CRITICAL/NEVER/MANDATORY directives that agents ignore, one clear behavioral instruction that's impossible to misinterpret.
- **Table-based step details**: replaced verbose per-step prose with a compact table mapping step → skill file → what to extract.
- **Removed redundant rules**: "ZERO discretion", "NEVER skip", "NEVER reorder" etc. all consolidated into workflow ordering + "user interrupts if they want to skip".

### Fixed
- Agent was reasoning "this is overkill" and skipping ensemble because the old CLAUDE.md had too many rules competing for attention. New version has one rule.

## [4.1.0] - 2026-04-08

### Changed
- **Step Details rewritten**: every step now explicitly reads the relevant skill's SKILL.md, extracts the methodology, and inlines it into the /scion-ensemble task prompt. Prevents agents from ignoring ensemble and running solo.
- **Methodology extraction pattern**: Gemini/Codex can now follow gstack skill methodologies (investigate 4-phase, review criteria, etc.) even though they can't read SKILL.md files directly — the methodology is embedded in the task prompt.
- **No diff/non-diff distinction**: all steps use /scion-ensemble uniformly. Same prompt for all 4 agents.

### Fixed
- Agent was ignoring Ensemble Execution Rule and running skills directly (solo) because Step Details said "Run /investigate" without mentioning /scion-ensemble.

## [4.0.0] - 2026-04-08

### Added
- **scion-ensemble skill**: New `/scion-ensemble` custom skill that spawns a 4-agent multi-model ensemble: 1 local Claude (Agent tool) + 3 Scion containers (Claude Opus, Gemini 2.5 Pro, Codex). Collects results and synthesizes into Consensus / Unique catches / Disagreements.
- **poll-agents.sh**: Standalone polling script for Scion agent completion. Supports per-model timeouts, quorum checking, and timestamped agent names.
- **Scion integration**: Diff-based workflow steps (review, bugbot) now use Google Scion for container-isolated multi-vendor AI review.

### Changed
- **Breaking**: Ensemble Execution Rule rewritten. Diff-based steps (review, bugbot) use `/scion-ensemble` (4 agents, 3 vendors). Non-diff steps retain the old Agent tool + Codex pattern until Phase 2.
- **Breaking**: Requires Scion CLI + Docker for full ensemble. Falls back to local-only Agent tool ensemble if unavailable.
- Step 7 (/review) and Step 8 (/bugbot) now reference `/scion-ensemble` instead of "Codex runs in parallel"

## [3.3.0] - 2026-04-08

### Changed
- Research-backed ensemble: structured perspectives, not just paraphrasing

## [3.0.0] - 2026-04-05

### Added
- **Ensemble Execution Rule**: Every workflow step spawns 3-10 identical subagents in parallel, synthesizes results into one report. Core leverage of the system.
- **Step 3: /research**: New mandatory step — search docs, codebase, existing solutions before planning. Uses search-first + documentation-lookup skills.
- **Step 6: /verify-test**: New mandatory step — generate throwaway code-based tests, run them, delete after. Tests never committed.
- **search-first skill**: Copied from affaan-m/everything-claude-code. Research existing tools/libraries before writing code.
- **documentation-lookup skill**: Copied from affaan-m/everything-claude-code. Fetch live docs via Context7 MCP.
- **verify-test skill**: Custom. Generate, run, and discard code-based verification tests.
- **Subagent Permission Rules**: Read-only by default (Read, Grep, Glob, Bash). Only coordinator can write files or use git.

### Changed
- **Breaking**: Workflow expanded from 7 steps to 9 steps (added /research and /verify-test)
- **Breaking**: Debugging flow expanded (added /research step)
- Ensemble rule applies to ALL steps (not just review/bugbot)

## [2.3.3] - 2026-03-27

### Fixed
- Clarified that /autoplan runs IMMEDIATELY after /slow-down approval, no asking
- "Plan acceptance ≠ plan review" — ExitPlanMode does not replace /autoplan
- Agent was skipping /autoplan entirely after user accepted a plan

## [2.3.2] - 2026-03-27

### Fixed
- Added "NEVER reorder steps" and "NEVER write code before /slow-down and /autoplan are done"
- Agent was running /investigate then jumping straight to implementation, skipping /slow-down and /autoplan entirely

## [2.3.1] - 2026-03-27

### Fixed
- Clarified that agent must NEVER ask "should we skip?" or suggest skipping
- User interrupts if they want to skip — agent just runs the next step

## [2.3.0] - 2026-03-27

### Changed
- **Breaking**: ALL workflow steps are now MANDATORY — agent has ZERO discretion to skip
- Removed all IF/THEN conditional logic that allowed agent to judge whether a step applies
- Only the user can skip a step by explicitly saying "skip [step]"
- Debugging flow also requires /slow-down and /autoplan (no shortcuts)

## [2.2.0] - 2026-03-27

### Added
- CHANGELOG.md for version history tracking
- Repo self-management rules in CLAUDE.md: agents must bump VERSION, update CHANGELOG, create git tag, and sync global files on every change

## [2.1.0] - 2026-03-26

### Changed
- Workflow now has 7 explicit numbered steps, not just 3 gates
- Every skill (office-hours, autoplan, plan-*, review, bugbot, ship) has a designated position with IF/THEN trigger rules
- Added debugging flow: /investigate → /slow-down → implementation → /review → /bugbot → /ship
- Added weekly retrospective: /retro with explicit trigger condition
- Removed separate "Skill Inventory" table — skills are defined by their workflow position

## [2.0.0] - 2026-03-26

### Changed
- **Breaking**: All content rewritten in English (was Korean)
- **Breaking**: CLAUDE.md restructured as enforceable IF/THEN gates (was advisory workflow)
- slow-down SKILL.md rewritten in English with original article quotes

### Added
- gstack added as git submodule at skills/gstack/
- VERSION file for version tracking

## [1.0.0] - 2026-03-26

### Added
- Initial setup: CLAUDE.md, settings.json, bugbot skill
- slow-down skill: 5-step pre-coding concretization process
- Global workflow rules: slow-down (mandatory) + bugbot (mandatory)
