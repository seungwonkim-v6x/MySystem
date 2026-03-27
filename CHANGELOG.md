# Changelog

All notable changes to MySystem are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

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
