# /ai-review-loop — Escalation & Message Templates (fixed)

Every owner-facing message follows its template exactly — greppable,
predictable at 2am. Placeholders in `<angle brackets>`. All lifecycle and
escalation comments are posted via `bin/post-reply.sh --issue --kind
lifecycle` and therefore carry the loop marker automatically.

## Lifecycle comments (DX1)

**started**
> 🔁 **ai-review-loop started** on `<repo>#<pr>` — round 1.
> Reviewers: `<id list>`. Warnings: `<none|list>`.
> Supervise: `/ai-review-loop --status` · Stop: `/ai-review-loop --close`

**awaiting-user** (also sent as PushNotification when available)
> ⏸ **ai-review-loop awaiting your decision** — round `<n>`, reason: `<reason>`.
> `<blocked_on — one line>`
> Recommended: `<recommended_action>`
> Resume: `<resume_command>`

**resumed**
> ▶️ **ai-review-loop resumed** — round `<n>` (decision: `<one line>`).

**closed / degraded-closed / closed-by-user / aborted**
> ✅ **ai-review-loop <closed|degraded-closed|closed-by-user|aborted>** after `<n>` rounds.
> `<per-round summary table>`
> `<degraded only:>` ⚠️ Unverified reviewers (timed out): `<ids>` — check the PR before merge.

## Escalation classes (awaiting.reason → template)

| reason | blocked_on | recommended_action | resume_command |
|---|---|---|---|
| `round-budget` | round `<n>` staged fixes = `<L>` lines (>20) | review the staged diff summary below | reply `approve round <n>` / `split` / `decline all` |
| `cumulative-budget` | loop total `<L>` lines (>40) | review all loop commits before more fixes | reply `continue` (resets nothing; acknowledges) or `--close` |
| `sensitive-path` | fix touches `<path>` (always-escalate list) | apply manually if wanted; loop never auto-fixes here | reply `acknowledged` |
| `reappearance` | `<fp>` re-reported after fix `<sha>` | the fix didn't take — inspect manually | reply `retry fix` / `mark misreading` / `--close` |
| `ci-red-on-loop-commit` | check `<name>` turned red on `<sha>` | inspect; loop never auto-reverts | reply `continue` after fixing / `--close` |
| `collect-failure` | collector failed twice: `<err>` | check gh auth / network / PR state | re-invoke `/ai-review-loop` |
| `state-write-failure` | cannot write state (`<err>`) / dirty worktree | fix disk/worktree state | re-invoke `/ai-review-loop` |
| `reviewer-contradiction` | `<id-a>` vs `<id-b>` disagree on `<cluster>` | pick a side or dismiss both | reply `side with <id>` / `dismiss` |
| `reconsideration-flag` | 3+ independent sources re-raise a rejected item: `<cluster>` | reconsider once — re-application is your call | reply `re-apply` / `keep rejection` |

## Reply templates (tier-A comments)

**valid (fixed)**
> Fixed in `<sha>`. `<one-line what changed>`. Evidence: `<file:line — quote or contract>`.

**misreading**
> No code change. `<evidence: quote of the actual code/contract that contradicts the reading>`.
> `<if a phrase caused it:>` The misleading phrase has been reworded in `<sha>`.

**prior-decision**
> Not applied: this was explicitly `<skipped|rejected>` at review on `<date>` — `<one-line rationale from the decision record>`. See workflow decision log.

**declined-by-policy** (sensitive path / budget decline)
> Not auto-applied: `<path>` is on the always-escalate list / declined at the round-`<n>` budget gate. Tracked for manual follow-up.

Greptile-specific classification/reply templates: use
`~/.claude/skills/gstack/review/greptile-triage.md` when present; these
generic templates are the fallback.
