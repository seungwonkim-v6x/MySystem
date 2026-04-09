# Changelog

All notable changes to MySystem are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [5.3.0] - 2026-04-09

### Added
- **Custom Subagents** (`~/.claude/agents/`): 7개 전용 서브에이전트 파일 생성
  - `ceo-reviewer.md`, `design-reviewer.md`, `eng-reviewer.md` (autoplan 역할별)
  - `code-reviewer.md`, `bug-hunter.md` (review/bugbot 전용)
  - `investigator.md`, `researcher.md` (investigate/research 전용)
- 각 에이전트가 model, tools, instructions를 자체 내장 — 매번 프롬프트 전달 불필요

### Changed
- Step Details 테이블: skill file 참조 → custom subagent 참조로 전환
- 서브에이전트 호출 방식: Agent tool + 긴 프롬프트 → 사전 정의된 `.claude/agents/` 파일 사용

## [5.2.0] - 2026-04-09

### Changed
- **/autoplan**: 동일 스킬 3회 반복 → 역할별 서브에이전트 (Agent 1=CEO, Agent 2=Design, Agent 3=Eng). 각 서브에이전트가 해당 역할의 SKILL.md를 직접 읽고 실행.
- **Implementation**: 앙상블에서 제외, 코디네이터가 직접 실행 (파일 쓰기 권한 필요)

## [5.1.0] - 2026-04-09

### Changed
- **Opus-only ensemble**: 서브에이전트 모델을 sonnet → opus로 변경. Codex CLI, Gemini CLI 제거 (불안정).
- **서브에이전트가 스킬을 직접 실행**: 코디네이터가 methodology를 요약/추출하지 않음. 각 서브에이전트가 SKILL.md를 직접 읽고 full methodology 실행.
- **3 perspectives 고정**: 3 opus subagents. 코디네이터는 합성만 담당.

### Fixed
- 서브에이전트 응답 1개만 오면 나머지 기다리지 않고 정리하던 문제 → ALL 3 반드시 대기
- 사용자 승인 없이 다음 워크플로우 단계로 넘어가던 문제 → 매 단계 후 명시적 승인 대기
- 서브에이전트 프롬프트가 300자 수준으로 잘리던 문제 → full context + "SKILL.md를 직접 읽어라" 지시

### Removed
- Codex CLI 통합 (호출 불안정)
- Gemini CLI 통합 (호출 불안정)

## [5.0.0] - 2026-04-09

### Changed
- **Base reverted to v3.3.0**: Scion 기반 v4.x 아키텍처 롤백. Step-detail 테이블(v4.2.0)은 유지.
- **Ensemble fixed at 5 perspectives**: 3 Claude sonnet subagents + Codex CLI + Gemini CLI. "3-5" 가변 범위 제거.
- **Codex CLI 플래그 현행화**: `--read-only` → `-s read-only`, `--write` → `-s workspace-write` (Codex v0.118.0)
- **Repo Self-Management**: skill sync를 copy에서 symlink으로 변경

### Added
- **Gemini CLI v0.36.0**: Codex와 함께 cross-model voice로 추가 (`gemini -p "<prompt>" --approval-mode plan -o text`)
- **Graceful degradation**: Codex/Gemini CLI 실패 시 Claude 앙상블만으로 진행
- **Long diff 처리**: tmp 파일 + stdin 파이프 패턴 명시

### Removed
- **Scion CLI 의존성**: "THE ONE RULE" (scion-ensemble 강제 호출) 제거
- **Docker/Scion container 기반 앙상블**: 4-agent Scion 아키텍처 전면 제거
- **Per-step 산문 설명**: step-detail 테이블로 대체

### Fixed
- v4.x 워크플로우가 Scion 미설치로 매 세션 실패하던 문제 해결
- Codex CLI v0.118.0과의 플래그 호환성 수정

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
