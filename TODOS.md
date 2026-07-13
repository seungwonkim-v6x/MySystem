# TODOS

Deferred work items. Format: what / why / effort (human → CC) / priority.

## From /ai-review-loop plan review (2026-07-03, /autoplan)

- [ ] **gemini CLI as tier-B reviewer row** — extend the /ai-review-loop registry when a second cross-model CLI is installed; one registry row + one bats case. Effort: S → S. P3. Blocked by: gemini CLI not installed.
- [ ] **PreToolUse hook enforcing `review-loop(rN):` push discipline** — harness-level guard that `git push` during an active loop round only pushes commits with the loop prefix; promoted from CHANGELOG Hook-enforcement candidates when the loop has real usage. Effort: M → S. P3.
- [ ] **shellcheck warning-level cleanup** — CI now lints hooks/scripts at error level (v0.49.0); ~8 pre-existing SC1007/SC2034/SC2088 warnings in parity scripts remain before raising to -S warning. Effort: S → S. P3.
- [ ] **Copilot GraphQL mark-outdated re-trigger fallback** — v2 path if the PAT-based `gh pr edit @copilot` re-trigger proves unreliable (see gh-copilot-review extension approach). Effort: M → S. P3. Trigger: cli-copilot retrigger fails twice on a real loop.
- [ ] **/ai-review-loop extra CLI verbs** — `--retry-reviewer <id>`, `--history`, standalone `--pause`/`--resume` (v1 covers these via escalation model + closing PR comment). Effort: S → S. P3. Trigger: real usage shows need.

## From harness-diet plan review (2026-07-13, /autoplan)

- [ ] **Outbound-data-transfer deny rules (curl POST, scp, gh gist)** — pareto rail from YOLO-gist research; deferred as false-positive-prone (over-blocking → rail abandonment). Effort: M → S. P3. Trigger: a real exfil near-miss or sandbox adoption.
- [ ] **Gate-removal quality review (ADR-0015)** — /retro transcript + hook-blocks.log sampling after ~30 tasks or by 2026-09-01; kill criterion: 2-3 same-class incidents (post-ship fixes on unreviewed work, skipped verification, hook false positives) → re-add ONE targeted rail (archived tier-guard lives in branch history). Effort: S → S. P2. Blocked by: v0.49.0 shipping.
- [ ] **Sandbox/container isolation layer** — strongest rail per research (survives prompt injection); an ocean today. Effort: XL → L. P3.
