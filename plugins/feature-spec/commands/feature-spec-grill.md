---
description: Interview stages only (phases 0-4) of a feature spec. Writes the design record, glossary and proposed ADRs — but no spec.
---

# Feature Spec — Grill

Run the grounding and interview stages of a feature spec and stop before
drafting.

## Read the skill first

Before doing anything, read `SKILL.md` from the `feature-spec-grill` skill in the
feature-spec plugin, and follow it exactly.

## Action

Run phases 0 through 4, then stop.

**Arguments:** `$ARGUMENTS`

Usage:
- `/feature-spec-grill <idea>` — default mode, up to 3 rounds
- `/feature-spec-grill <idea> --fast|--deep` — depth modes, as the full command
- `/feature-spec-grill <slug> --resume` — continue an unfinished interview
- `/feature-spec-grill <idea> --scope <path>` — confine grounding

## This command writes files

**It is not a dry run.** It creates the spec directory and writes the design
record, the glossary entries decided so far, and any promoted ADRs as
`Status: Proposed`.

It does **not** write `spec.md`. Run `/feature-spec-write <slug>` for that — in
this session or a later one.

## Key reminders

- Sets `Next phase: 5` in the design record so the write stage can pick it up
- Abandoning here leaves the record and glossary in place on purpose — they are
  decisions the user made
