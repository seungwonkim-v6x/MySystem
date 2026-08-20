# Testing the Pi Environment

The active runtime is Pi. Legacy Bats suites cover the retired Claude/Codex surface and are not the release gate for Pi.

## Smoke checks

```bash
node --experimental-strip-types --check .pi/extensions/pi-safety.ts
node --experimental-strip-types tests/pi-environment.mjs
node -e "JSON.parse(require('fs').readFileSync('.pi/settings.json')); console.log('Pi settings: PASS')"
```

For a live provider smoke test:

```bash
pi --no-session --approve -p 'Reply only: ready'
```

## Safety checks

The extension should block or confirm:

- writes to `.git/`, `.env*`, private-key files, and runtime auth files;
- recursive deletion of system/home paths;
- `dd`/`mkfs` device operations and fork bombs;
- downloaded content piped into a shell;
- `git push --force` to `main`/`master` and `git commit --no-verify`;
- ordinary `git commit`, `git push`, reset, merge, rebase, and GitHub publication through an interactive confirmation.

Non-interactive Pi modes block confirmation-required commands because no human dialog is available.

## Context-budget checks

Pi's startup header shows loaded context files, skills, prompts, and extensions. `/session` shows token/cache usage. Keep the active project resources small; do not add permanent procedural prose when an on-demand prompt or skill is sufficient.

Automatic compaction remains enabled with a response reserve. Use `/compact` or a fresh session when changing domains; full session history remains available through Pi's session tree.

## Legacy verification

If the retired Claude/Codex surface is intentionally audited, use the old Bats suite and parity doctor explicitly. Do not run those checks from a normal Pi session or treat their result as Pi readiness.
