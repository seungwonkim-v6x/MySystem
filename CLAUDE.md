# Personal Rules

## Pre-Commit Bug Review (MANDATORY)

Before creating any git commit or push, **always run `/bugbot` first**.

- Launch a separate Agent with fresh eyes to review the branch diff
- Only proceed with commit/push after the review is clean or user acknowledges the findings
- This applies to ALL projects, not just specific ones
- Skip only if the user explicitly says to skip the review (e.g., "skip bugbot", "just commit")

## Slow Down — Pre-Coding Concretization (MANDATORY)

Before writing any implementation code, **always run `/slow-down` first**.

- Triggers when the user requests: feature implementation, bug fix, refactoring, or any coding work
- Runs the 5-step concretization process: problem definition, done criteria, scope, risk pre-mortem, approach alignment
- **Do NOT write code until the user approves the concretization output**
- This applies to ALL projects, not just specific ones
- Skip only if the user explicitly says to skip (e.g., "바로 해줘", "skip slow-down", "구체화 건너뛰기")
- Also skip for: trivial fixes (typos, one-liner), already-planned tickets (`/implement-ticket`), questions/research

## Kling 3.0 Prompting Skill

When evaluating, writing, or improving Kling video prompts, read and apply the skill reference at:
`~/.agents/skills/kling-3-prompting/SKILL.md`
