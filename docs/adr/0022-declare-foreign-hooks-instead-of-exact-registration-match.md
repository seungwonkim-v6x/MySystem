# ADR-0022: Declare host-owned hooks in the contract instead of demanding an exact registration match

- **Status**: Accepted
- **Date**: 2026-08-07
- **Author**: seungwon-v6x
- **Tags**: codex-parity, hooks, safety, harness

<!-- mysystem:managed-start (intentionally empty — reserved for future tooling) -->
<!-- mysystem:managed-end -->

## Context

`validate_hook_registration()` in `scripts/render-codex-agents.sh` compared the
canonical `codex/hooks.json` against the contract with exact set equality:

```python
if normalize(actual) != normalize(expected):
    raise SystemExit("canonical hook registration does not match the contract")
```

Orca, the host that launches the agent runtime, continuously reinjects eight
wildcard telemetry tuples (`PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`,
`SubagentStart`, `SubagentStop`, `UserPromptSubmit`, `PermissionRequest`) into
that file and drops a `.bak` beside it. The injection is purely additive — a
diff against `HEAD` confirms all seven reviewed tuples survive untouched — but
exact equality cannot express "additive is fine".

The consequence was worse than a spurious warning. `codex-parity-doctor.sh`
treats `CONTRACT_INVALID` as fatal and exits immediately, so the live install
reported `PASS=0 WARN=0 FAIL=1`: the other thirty-plus checks never ran. The
session-start banner surfaced by `hooks/update-skills.sh` was therefore not
noise about one stale field — it marked a checker that had stopped checking.

Reverting the injection is not available. It is reapplied on every Orca launch,
and a revert loop was already rejected as a maintenance sink.

v0.52.2 solved the same problem one layer down, for tests only, in
`tests/helpers/orca-sanitize.bash` — identifying Orca's entries by the
`.orca/agent-hooks` path in their command. That fix kept CI green while leaving
the live install red.

## Decision

We will add a `foreign_hooks_allowed` array to `codex/parity-contract.json`
whose entries pin one host command each:

```json
{ "path": "$HOME/.orca/agent-hooks/codex-hook.sh",
  "command_sha256": "6b82489a…" }
```

A registration entry is exempt from the reviewed set only when the sha256 of its
command matches a declared digest. The digest is taken over the command's
*portable* form — the caller's `$HOME` rewritten back to the literal `$HOME` —
so the contract stays machine-independent and the exemption still fires for a
host that writes `$HOME/…` directly. `path` is not decoration: an entry whose
command does not reference its own declared path is a contract error, not a
silent pass.

Exemption is by digest, not by mentioning a path. This distinction is the whole
point. An earlier draft of this decision exempted any command *containing* a
declared path, and review reproduced six ways through it — a comment
(`curl … | sh   # $HOME/.orca/…/codex-hook.sh`), a `;`-chained payload appended
to the real command, a prefix over-match onto `codex-hook.sh.bak` and
`codex-hook.sh-evil-payload`, and a dead-code mention. All six now fail.
Token-equality via `shlex.split` was considered and rejected: it stops the
prefix and comment cases but not the chained one.

Everything else stays strict. The seven contracted tuples must still match
exactly — a missing, retargeted, or inert reviewed hook still fails. A host we
did not declare still fails. The contract model requires each entry to be an
object with exactly `path` and `command_sha256`, the path `$HOME/`-rooted with
no `..`, no second `$`, and no trailing `/`, so `["$HOME/"]` or
`["$HOME/.orca/"]` cannot widen the exemption to a directory.

Only `codex-hook.sh` is declared. `claude-hook.sh` appears solely in
`settings.json`, which this validator never reads, so declaring it would be dead
surface.

This decision does not cover the doctor's fatal-exit behavior on
`CONTRACT_INVALID`, and it does not make the doctor workspace-aware — running it
from a clone still reports link drift against `~/.claude`.

## Alternatives considered

- **A: Superset semantics** — accept any registration containing the contracted
  tuples, ignore all extras. Rejected: it silently accepts hooks from *any*
  source, which is precisely the detection the contract exists to provide.
- **B: Leave the validator alone; stop the doctor short-circuiting** — rejected
  as the primary fix because the banner would keep firing every session, which
  is how a real regression gets trained into background noise. Still worth doing
  on its own merits.
- **C: Revert Orca's injection on each run** — rejected: reapplied on every
  launch, so it is an unwinnable loop against the host.
- **D: Hardcode the `.orca/agent-hooks` regex in the validator**, mirroring the
  test helper — rejected: an undeclared, unreviewable exemption buried in a
  script is exactly what the narrow contract is meant to replace.
- **E: Exempt by declared path (substring or token match)** — rejected after
  review reproduced six bypasses; see Decision. Cheaper to maintain than a
  digest, but it does not deliver the property this ADR claims.

## Consequences

- ✓ The live install's parity doctor runs all thirty-four checks again instead
  of aborting at check one. Verified against the real polluted registration:
  `PASS=0 FAIL=1` → `PASS=31 WARN=3 FAIL=9`.
- ✓ The session-start banner goes quiet for a cause that is not a defect, so the
  next time it fires it means something.
- ✓ Exactly one host command is exempt, recorded in a reviewed file. Changing it
  is a contract diff carrying a new digest, not an invisible drift.
- ✗ **Every Orca release that edits its hook command breaks the digest**, which
  fails the validator, aborts the doctor, and brings the banner back until the
  contract is re-approved. This is not hypothetical: Orca has already changed the
  command once, rewriting the `else` branch from `cat >/dev/null` to
  `{ command -p cat 2>/dev/null || cat; }`. Accepted deliberately — the doctor's
  existing `ORCA_VERSION_UNTESTED` warning already demands a contract review on
  host upgrade, so the re-approval lands where a review was owed anyway.
  Refresh with `tests/fixtures/codex-parity/orca-hook-command.txt` plus the
  contract digest, together, in one reviewed commit.
- ✗ The digest covers the command string, not the script it runs. A compromised
  `codex-hook.sh` whose *invocation* is unchanged still passes. Content-level
  trust for host scripts is out of scope, as it already is for our own hooks.
- ✗ Two places now encode the same knowledge: the contract field and
  `tests/helpers/orca-sanitize.bash`, which still identifies Orca entries by the
  `.orca/agent-hooks` path. The helper could read the contract; it was left alone
  to keep this change to the reported defect.
- ? Whether the re-approval cost is tolerable in practice. If Orca churns its
  command more than about once a quarter, the digest becomes the new banner
  source and this should move to a narrower structural match.

## References

- Related ADR: ADR-0011 (provider-pluggable vendoring), ADR-0016 (Codex surface)
- Code: `scripts/render-codex-agents.sh` (`validate_hook_registration`,
  `validate_contract_model`), `codex/parity-contract.json`,
  `tests/fixtures/codex-parity/orca-hook-command.txt`,
  `tests/helpers/orca-sanitize.bash`
- Tests: `tests/codex-parity.bats` — "contract exempts the host command it pins
  by digest", "the pinned host digest still describes the captured host
  command", "the contract model refuses a host entry that widens past one named
  file", "the host exemption cannot be borrowed by a command that only mentions
  the path"

## How this file is maintained

- ADR numbering is monotonic per project. Don't reuse numbers; mark superseded instead.
- Rewrite history only by adding a new ADR that supersedes the old one.
- An ADR is deliberate. Don't auto-generate from PR descriptions.
