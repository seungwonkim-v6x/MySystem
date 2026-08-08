# TODOS

Deferred work items. Format: what / why / effort (human → CC) / priority.

## From /ai-review-loop plan review (2026-07-03, /autoplan)

- [x] **All four Step-9 items obsolete** — gemini tier-B reviewer row, the `review-loop(rN):` push-discipline PreToolUse hook, the Copilot GraphQL re-trigger fallback, and the extra `/ai-review-loop` CLI verbs all died with the skill (v0.54.0, ADR-0018). Restoring any of them means restoring Step 9 first.
- [ ] **shellcheck warning-level cleanup** — CI now lints hooks/scripts at error level (v0.49.0); ~8 pre-existing SC1007/SC2034/SC2088 warnings in parity scripts remain before raising to -S warning. Effort: S → S. P3.

## From harness-diet plan review (2026-07-13, /autoplan)

- [ ] **Outbound-data-transfer deny rules (curl POST, scp, gh gist)** — pareto rail from YOLO-gist research; deferred as false-positive-prone (over-blocking → rail abandonment). Effort: M → S. P3. Trigger: a real exfil near-miss or sandbox adoption.
- [x] **Gate-removal quality review (ADR-0015)** — obsolete: ADR-0016 (v0.50.0, 2026-07-21) restored the gated workflow and retired the ADR-0015 kill criterion before the review window elapsed.
- [ ] **Sandbox/container isolation layer** — strongest rail per research (survives prompt injection); an ocean today. Effort: XL → L. P3.
- [ ] **Audit non-final `[[ ]]` assertions in bats suites** — bats does not fail a test when a non-final `[[ ]]` returns false (verified 1.13.0), so mid-test assertions may be silently unenforced; sweep tests/*.bats and either move assertions last, chain `|| false`, or adopt bats-assert. Effort: S → S. P2. Trigger: found while fixing the test-72 CI failure (2026-07-13).

## From the v0.59.0 ship (2026-08-08)

- [ ] **Root-cause the concurrent-installer CI flake** — `tests/codex-parity.bats`'s
  "concurrent installers" case failed once on a macOS runner while the same commit
  passed on a sibling runner; 26 local runs including under CPU load could not
  reproduce it. Full handoff with ruled-out hypotheses, prime suspects at
  `scripts/codex-parity-lib.sh:426-429`, and acceptance criteria:
  [`docs/handoff/ci-concurrent-installer-flake.md`](docs/handoff/ci-concurrent-installer-flake.md).
  Effort: M → M. P3. Trigger: the next occurrence — the test now prints the losing
  installer's log, which should identify the failure code on its own.
