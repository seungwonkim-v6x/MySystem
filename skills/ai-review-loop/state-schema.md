# /ai-review-loop — State File Schema (frozen)

`schema_version: 1`. One file per PR:
`~/.gstack/projects/<slug>/ai-review-loop/pr-<N>.json`, where `<slug>` is
the output of `~/.claude/skills/gstack/bin/gstack-slug` (same derivation
every gstack skill uses). Written atomically (mktemp + mv) by the skill
layer only; helper scripts are pure readers.

An ACTIVE loop with a `schema_version` other than 1 fails closed: the skill
stops with "finish or `--close` this loop before upgrading". Closed files
are never migrated. Corrupt (unparsable) JSON — any version — routes
through recovery: rename to `pr-<N>.json.corrupt`, re-init, reconstruct
`replied` state from loop reply markers on the PR.

```jsonc
{
  "schema_version": 1,
  "pr": 137,
  "repo": "owner/repo",
  "branch": "feat/x",

  // Loop lifecycle. "awaiting-user" = paused on an escalation, not failed.
  // "aborted" = PR merged/closed or external commits mid-loop (SKILL.md
  // abort conditions); a terminal state like the closed-* values.
  "loop_status": "active | awaiting-user | closed | degraded-closed | closed-by-user | aborted",

  // Present ONLY while loop_status == "awaiting-user".
  "awaiting": {
    "reason": "cumulative-budget | round-budget | sensitive-path | reappearance | ci-red-on-loop-commit | collect-failure | state-write-failure | reviewer-contradiction | reconsideration-flag",
    "blocked_on": "one-line human description",
    "recommended_action": "one-line recommendation",
    "resume_command": "exact reply or command that resumes"
  },

  // Round sub-state for idempotent resume after compaction/wakeup.
  "phase": "waiting | triaging | fixing | replying",
  "round": 3,

  // PR head SHA when the loop started — anchors round-1 convergence.
  "loop_start_head_sha": "abc123...",
  // HEAD before this round's first staged fix. Reset at each round start.
  "round_base_sha": "def456...",
  // gh pr checks summary at loop start: "green" | "red" | "none".
  "ci_baseline": "green",

  // Advisory lock (EA9). Heartbeat refreshed on every Monitor tick (DX7).
  // Resume from another session requires heartbeat older than 30 min or
  // --take-over.
  "session_id": "sess-...",
  "heartbeat_ts": "2026-07-03T11:00:00Z",

  // Reviewer registry (detect-reviewers.sh output, plus runtime fields).
  "registry": [
    {
      "id": "copilot",
      "tier": "A",                       // A | B | C
      "login": "copilot-pull-request-reviewer[bot]",  // tier A only
      "retrigger": "cli-copilot",        // cli-copilot | comment-command:<text> | push-triggered | none | local
      "reviewer_status": "active",       // expected | active | timeout | skipped-by-user
                                         //   expected = known repo bot seeded before it has posted on this PR
                                         //              (loop waits for + re-triggers it); becomes active on first review
      "last_reviewed_sha": "abc123...",  // last head SHA this reviewer produced output for
      "requested_at": ""                 // ISO of last re-trigger, "" if none pending
    }
  ],

  // Per-surface incremental cursors. All three surfaces are fully paged +
  // id-filtered (no ETag): per-page list ETags can 304 an unchanged page 1
  // while new items append to a later page, which would mask findings and
  // fake convergence. The full page walk is the positive confirmation.
  // `reviews.etag` is retained as an always-"" field for output-shape compat.
  "cursors": {
    "reviews":         { "last_id": 0, "etag": "" },
    "inline_comments": { "last_id": 0 },
    "issue_comments":  { "last_id": 0 }
  },

  // body sha256 per already-seen ISSUE comment id — edited-in-place
  // detection (EA4). v1 scope: issue comments only. Review-summary bodies
  // and inline review comments are id-filtered only (see SKILL.md
  // "Self-verification status"); a Copilot-style review summary edited in
  // place is a known v1 blind spot.
  "comment_hashes": { "123456": "sha256hex" },

  // Finding ledger. Key = "<path>#<gist>" (fingerprint identity; line is
  // metadata only). Same path+gist = same finding unless both are
  // simultaneously open in one round (EA6).
  "fingerprints": {
    "src/foo.ts#null check missing parser": {
      "line": 42,                        // remapped after each fix commit
      "sources": ["copilot", "codex"],
      "round_first_seen": 1,
      "classification": "pending | valid | misreading | prior-decision",
      "similar_to": [],                  // judgment-layer cross-source cluster (EA17)
      "fixed_in": null,                  // commit sha once committed
      "replied_comment_ids": [123456],
      "reply_status": "done | pending | n/a"   // n/a for tier B/C findings
    }
  },

  // Untriaged carryover queue (per-round 30-finding triage cap, EA7).
  // Convergence REQUIRES this to be empty.
  "untriaged": ["src/bar.ts#some finding gist"],

  // Budget accounting (DX3: staged-diff mechanics; EA8).
  "cumulative_changed_lines": 12,        // sum of APPROVED rounds' staged diffs
  "loop_commits": ["sha1", "sha2"],      // commits this loop pushed (review-loop(rN): prefix)

  "escalations": [
    { "round": 2, "reason": "sensitive-path", "detail": "hooks/x.sh", "resolved": "declined" }
  ],

  // Per-round audit for --status and the closing PR comment.
  "rounds": [
    { "n": 1, "new_findings": 3, "valid": 1, "misreading": 1,
      "prior_decision": 1, "fixed": 1, "replied": 3, "changed_lines": 4,
      "converged": false, "notes": "" }
  ]
}
```

## Enums referenced elsewhere

- **Convergence predicate (canonical):** a round converges when
  `untriaged == []` across all fetched surfaces AND zero findings in the
  round were classified `valid`. Rounds are unbounded (user decision
  2026-07-03, final gate — no wall-clock or round-count pause; do not
  re-add one).
- **degraded-closed:** converged, but at least one previously-active
  tier-A row ended `reviewer_status: "timeout"` — closing summary must
  list those rows as "unverified — check PR before merge".
- **Reply marker** (EA5), embedded in every loop-posted comment:
  `<!-- ai-review-loop:v1 fp=<sha256-of-fingerprint-key> round=N kind=<reply|lifecycle> -->`
