---
kind: design-rider
read-at: "Step 4 (material UI change) + Step 5 design-review / Quick Visual Check"
precedence: "frontend-design wins on taste; the BANS below are hard and always apply"
---

# DESIGN.md — project design rider

> **How to tune this (for the human):** change the three preset words in "Design dials"
> below (e.g. `bold` → `calm`). That's the whole knob. You never type a number. If the
> agent's design output feels off, say what's wrong in plain words ("too busy", "too
> flat") and it maps that back to these. Delete any ban that doesn't fit this project.

This rider is the *machine-checkable* half of Step 4 design discipline. The *taste* half is
`/frontend-design` (Anthropic plugin), loaded alongside it. On conflict, frontend-design wins
on aesthetics; the **Hard bans** here are objective and always apply.

## Design dials (named presets → the agent applies the per-preset descriptions below)

- **Variance** (layout boldness): `calm` | `balanced` | **`bold`**  ← default `bold`
  - calm = symmetric, safe, centered. bold = asymmetric, split-screen, intentional whitespace.
- **Motion** (animation intensity): `still` | **`balanced`** | `cinematic`  ← default `balanced`
  - still = no movement. cinematic = orchestrated page-load / scroll reveals / physics.
- **Density** (information packing): **`airy`** | `balanced` | `packed`  ← default `airy`
  - airy = gallery, lots of breathing room. packed = dashboard / cockpit, data-dense.

Defaults (`bold` / `balanced` / `airy`) are the taste-skill baseline. Adjust per project.

## Hard bans (objective — always enforced, regardless of taste layer)

- **No `h-screen` for full-height sections** → use `min-h-[100dvh]` (prevents iOS Safari jump).
- **No emoji as icons / UI symbols** → use a real icon set (Radix, Phosphor) or clean SVG.
- **No flex-percentage math** (`w-[calc(33%-1rem)]`) → use CSS Grid (`grid grid-cols-3 gap-6`).
- **No generic spinner** for loading → use skeleton loaders matching the final layout.
- **Every data view must implement loading / empty / error states** — not just the success state.
- **When Variance is `bold`: no centered hero/H1** → split, left-aligned, or asymmetric layout.
- **When Density is `packed`: no generic card-in-card** → group with `border-t` / `divide-y` / whitespace; cards only when elevation encodes real hierarchy.

## Notes

- This is a *rider*, not the whole picture — `/frontend-design` carries palette, typography,
  and the signature move. Keep this file short; it only holds bans + dials.
- Adapted from **taste-skill** (`github.com/Leonxlnx/taste-skill`, MIT © 2026 Leonxlnx) —
  machine-checkable subset only; the framework-specific (React/Next/Tailwind) stack guards
  were intentionally left out so this rider stays stack-agnostic.
