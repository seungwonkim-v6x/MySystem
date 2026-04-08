# Changelog

All notable changes to MySystem are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

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
