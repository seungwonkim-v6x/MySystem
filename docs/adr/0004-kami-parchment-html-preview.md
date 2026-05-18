# ADR-0004: Auto-render assistant turns as kami-parchment HTML preview

- **Status**: Accepted
- **Date**: 2026-05-17
- **Author**: seungwon-v6x
- **Tags**: ux, hooks, preview

## Context

Workflow output — `/autoplan` plans, `/deep-research` reports, `/review` findings, `/requesting-code-review` results — is consistently long and structured. Reading it in Claude Code's CLI sidebar or terminal works but is suboptimal: markdown headings flatten, tables wrap, code blocks lack syntax highlighting, and review-style content (which expects scanning, not linear reading) doesn't fit the chat surface.

The user explicitly framed the pain: "I want to feel like I'm reading a website, not a CLI dump." Candidate solutions ranged from "rely on Markdown preview" to "adopt html-anything (a full Next.js HTML editor)". The right shape was somewhere in between: a thin transform pipeline that produces a readable static page after every substantive assistant turn.

## Decision

We will add a `Stop` hook (`hooks/preview-stop.sh`) that captures the last *substantive* assistant text turn (≥600 chars OR contains markdown structure) from the transcript JSONL, embeds it base64-encoded into a static HTML template (`hooks/preview-template.html`) using a kami-parchment visual system adapted from nexu-io/html-anything's `doc-kami-parchment` skill (Apache-2.0, attribution preserved), and writes `~/.claude/previews/latest.{md,html}`. The user opens `latest.html` once in VS Code's Live Preview extension (or a browser tab); it auto-reloads on every new write.

Boundary: the hook does *not* call `open` — that would spawn a new browser tab on every session start. Viewer setup is a one-time user action.

## Alternatives considered

- **A: Rely on VS Code's built-in Markdown Preview** — rejected because it doesn't preserve the kami aesthetic and forces the user to open each plan/`.md` file manually
- **B: Adopt nexu-io/html-anything wholesale** — rejected because it's a Next.js app with 75 skills covering many surfaces (decks, posters, magazines); wrong shape and re-introduces skill sprawl
- **C: Generate HTML for *every* assistant response** — rejected because the browser would flash on every chat reply; short ack-style responses have no value as a preview
- **D: Open the preview in Claude Code's chat UI directly** — rejected because Claude Code renders markdown there already; the whole point is a richer surface

## Consequences

- ✓ Substantive assistant output is now readable in a dedicated panel with proper typography, code highlighting, and table layout
- ✓ Hook is ~80 lines of bash + ~150 lines of static HTML; trivial to maintain
- ✓ Visual system attributable to a real published skill (no original CSS to maintain)
- ✗ The "substantive" filter (≥600 chars OR markdown structure) is heuristic; short-but-important replies will not surface (mitigated by user manually opening `latest.md`)
- ✗ Hook activation is session-scoped — adding the hook mid-session does not activate it until the next session restart
- ? Whether the filter threshold (600 chars) is right; may need tuning based on real use

## References

- CHANGELOG: v0.32.0
- Code: `hooks/preview-stop.sh`, `hooks/preview-template.html`
- Inspired by: [nexu-io/html-anything](https://github.com/nexu-io/html-anything) doc-kami-parchment skill (Apache-2.0)
