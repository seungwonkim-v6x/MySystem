# Personal Rules

## Pre-Commit Bug Review (MANDATORY)

Before creating any git commit or push, **always run `/bugbot` first**.

- Launch a separate Agent with fresh eyes to review the branch diff
- Only proceed with commit/push after the review is clean or user acknowledges the findings
- This applies to ALL projects, not just specific ones
- Skip only if the user explicitly says to skip the review (e.g., "skip bugbot", "just commit")
