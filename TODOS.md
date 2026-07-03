# TODOS

Deferred work items. Format: what / why / effort (human → CC) / priority.

## From /ai-review-loop plan review (2026-07-03, /autoplan)

- [ ] **gemini CLI as tier-B reviewer row** — extend the /ai-review-loop registry when a second cross-model CLI is installed; one registry row + one bats case. Effort: S → S. P3. Blocked by: gemini CLI not installed.
- [ ] **PreToolUse hook enforcing `review-loop(rN):` push discipline** — harness-level guard that `git push` during an active loop round only pushes commits with the loop prefix; promoted from CHANGELOG Hook-enforcement candidates when the loop has real usage. Effort: M → S. P3.
- [ ] **shellcheck in CI** — lint all repo bash (hooks/ + skills/*/bin/) in test.yml. Effort: S → S. P3.
- [ ] **Copilot GraphQL mark-outdated re-trigger fallback** — v2 path if the PAT-based `gh pr edit @copilot` re-trigger proves unreliable (see gh-copilot-review extension approach). Effort: M → S. P3. Trigger: cli-copilot retrigger fails twice on a real loop.
- [ ] **/ai-review-loop extra CLI verbs** — `--retry-reviewer <id>`, `--history`, standalone `--pause`/`--resume` (v1 covers these via escalation model + closing PR comment). Effort: S → S. P3. Trigger: real usage shows need.
