# ADR-0017: Merge Steps 6+7 into one concurrent two-pass review gate

Date: 2026-07-24
Status: Accepted
Amends: ADR-0016 (restore the gated 9-step workflow) — changes the Step 6/7 shape only; all other gates stand.

## Context

The former workflow ran two sequential pre-merge review steps, each with its own
approval gate: Step 6 `/review` (gstack) then Step 7 `/requesting-code-review`
(superpowers). The owner judged the double *gate* redundant.

This started as an investigation into adopting `alibaba/open-code-review` (OCR)
to replace both steps in delegation mode (subscription auth, no API key). The
full workflow was run on the idea (office-hours → deep-research → autoplan
gauntlet). Two findings killed the OCR path and reshaped the change:

1. **OCR in delegation mode adds no intelligence.** `ocr delegate` only does
   deterministic file selection + rule-doc injection; the actual review is
   performed by a fresh Claude subagent. Its fine-tuned engine (`ocr review`)
   requires an API key and is a CI-bot fit (Step 9), not a Step 6 fit. Adopting
   it at Step 6 buys a file-picker at the cost of a version-pinned third-party
   binary, a re-audit obligation on every bump, and a rule-injection surface
   (project/global `.opencodereview/rule.json` is untrusted in team repos and is
   rendered verbatim into the reviewing subagent's prompt). The security vetting
   also surfaced that project rules *replace* embedded rules unless
   `merge_system_rule: true`, and that the npm install runs a networked
   postinstall binary download. Net: cost without intelligence gain.

2. **The two passes are not redundant — the two *gates* were.** `/review` runs
   in-session (context-rich: knows the plan and repo invariants; catches
   "violates a known invariant / unsafe against our schema"). `/requesting-code-review`
   runs as a fresh-context subagent (context-poor by design; catches what the
   author and a context-sharing reviewer are blind to). They catch different bug
   classes. Deleting either loses coverage.

## Decision

Merge Steps 6 and 7 into a single **Step 6: Concurrent Two-Pass Review (one gate)**:

- Run both passes concurrently — `/review` in-session while
  `/requesting-code-review`'s fresh subagent runs in the background.
- Merge and dedupe findings into one table; present **one** approval gate.
- Both skills stay whitelisted and unchanged; nothing is de-whitelisted.
- Step 9 (`/ai-review-loop`) reviews the PR artifact and remains distinct.
- Do **not** adopt OCR anywhere in this repo's workflow (no Step 6 delegation,
  no Step 9 CI). Step 9 continues to auto-ingest whatever bots comment on a PR.

**Numbering:** Step 7 is removed; Step 8 (`/ship`) and Step 9 (`/ai-review-loop`)
keep their numbers. `/ai-review-loop` is referenced as "Step 9" across its own
SKILL.md and ADR-0012, so renumbering would cascade; the deliberate gap at 7 is
cheaper and is documented here. The workflow is still called 9-step; it has 8
active steps with an intentional gap.

## Alternatives rejected

- **Adopt OCR at Step 6 (delegation).** Finding 1 above — cost without
  intelligence gain; global scope adds a rule-injection surface on team repos.
- **Collapse to a single pass** (one fresh subagent + a static checklist).
  Simpler, but loses `/review`'s in-session context-rich perspective (Finding 2).
- **Keep the sequential two-gate design.** This is what the owner wanted to
  remove; the double gate was the actual friction.

## Consequences

- Pre-merge coverage is unchanged (both perspectives retained); one fewer
  approval wait; wall-clock drops from sequential to parallel. Token/work total
  is unchanged — both passes still run.
- No new dependency, no supply-chain/pin-audit tax, no untrusted-rule surface;
  safe under the global scope of this CLAUDE.md (applies to team repos too).
- Kill criterion: if the merged single gate is observed to let a class of bug
  through that the old sequential cross-check caught (2-3 real incidents),
  reconsider restoring a second gate. No "remove once X" — this is durable.
