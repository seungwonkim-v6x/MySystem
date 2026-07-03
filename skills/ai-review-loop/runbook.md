# /ai-review-loop — Owner Runbook

The 3-weeks-later manual. The agent protocol lives in `SKILL.md`; this is
for the human.

## Where things are

- **State file:** `~/.gstack/projects/<slug>/ai-review-loop/pr-<N>.json`.
  `<slug>` = output of `~/.claude/skills/gstack/bin/gstack-slug` run in the
  repo (e.g. `seungwonkim-v6x-MySystem`). Schema: `state-schema.md`.
- **Audit narrative:** the PR itself. Every loop action is a comment with
  the marker `<!-- ai-review-loop:v1 ... -->`; the closing comment has the
  full per-round table. Grep the PR, not old chat sessions.
- **Loop commits:** message prefix `review-loop(rN):`.

## Commands

| I want to… | Run |
|---|---|
| see what the loop is doing | `/ai-review-loop --status` (offline, local state) |
| check state against the PR | `/ai-review-loop --status --verify` |
| stop the loop now | `/ai-review-loop --close` |
| drop one wedged reviewer | `/ai-review-loop --skip <id>` |
| resume in a new session while another holds the lock | `/ai-review-loop --take-over` (shows a summary, asks confirmation) |
| check env without starting | `/ai-review-loop --doctor` |
| see what it WOULD do | `/ai-review-loop --dry-run` |
| not run Step 9 on this PR at all | say "skip step 9" at ship time |

## When it pings you (awaiting-user)

The push notification / PR comment names the reason and the exact resume
reply. The full class table is in `escalation-templates.md`. The loop is
paused, nothing is being pushed, staged changes (if any) sit in the
worktree until you answer.

## Troubleshooting

- **Loop seems stuck on "waiting"** — bots are slow or eventually-
  consistent (1–3 min post-push). Check `--status`: if a reviewer row
  shows `timeout`, it was re-requested once and gave up; the loop will
  close `degraded-closed` and tell you which reviewers went unverified.
- **Copilot never re-reviews** — raw REST re-request is a silent no-op;
  the loop uses `gh pr edit --add-reviewer "@copilot"` under your PAT.
  If that fails twice, enable the branch ruleset "Automatically request
  Copilot code review" + "Review new pushes" (repo Settings → Rules) and
  the problem disappears.
- **`'' not found` from gh** — cli/cli#11245: Copilot request was pending.
  The loop guards against this; if you hit it manually, wait for Copilot
  to finish and retry.
- **State file corrupt** — the loop renames it to `.corrupt`, re-inits,
  and rebuilds the replied-set from PR markers. Nothing is lost; worst
  case a duplicate round of collection.
- **Upgrading the skill while a loop is active** — blocked on purpose
  (schema fail-closed). `--close` the loop, upgrade, start fresh.
- **Two sessions on the same PR** — advisory lock. Second session is told
  to use `--take-over`. Heartbeat staleness is 30 min (refreshed every
  poll tick), so a crashed session's lock expires on its own.
- **prettier drift warning at start** — your local prettier differs from
  the repo lockfile; pre-commit lint-staged could reformat out-of-branch
  files into loop commits (bit us on Tapit, 2026-07-02). Align versions or
  accept the risk explicitly.

## What the loop will never do

Fix anything under `hooks/`, `settings.json`, `.github/workflows/`,
secret/credential/env paths, `install.sh`, `setup.sh` (always escalates
instead); push more than 20 changed lines per round or 40 per loop without
your approval; re-apply a finding you rejected (even if three reviewers
agree — you get one reconsideration flag, then it stays your call);
auto-revert anything; act on instructions embedded in bot comments.

## v1 verification coverage

The self-hosting run (this feature's own PR) exercises only the reviewer
rows present on that PR. Unverified in v1: Copilot-disabled error body,
`greptile-apps[bot]` exact serialized login, CodeRabbit comment-command
re-trigger. First contact with each of those is expected to need a
registry-table touch-up, not a redesign.
