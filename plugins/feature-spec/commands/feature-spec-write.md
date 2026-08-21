---
description: Draft, critique and write a feature spec (phases 5-7) from an existing design record.
---

# Feature Spec — Write

Draft the spec from an existing design record, run the critic against it, and
write the files.

## Read the skill first

Before doing anything, read `SKILL.md` from the `feature-spec-write` skill in the
feature-spec plugin, and follow it exactly.

## Action

Run phases 5 through 7 against the design record for the given slug.

**Arguments:** `$ARGUMENTS`

Usage:
- `/feature-spec-write <slug>` — draft, critique and write

**If no arguments are provided:** list the slugs that have a design record but no
spec, and ask which one.

## Key reminders

- Designed to run in a **fresh session** — it reads the design record and the
  files that record names, and nothing else
- Every requirement and success criterion carries a source tag; anything
  untraceable is cut or marked, never asserted
- A slug whose spec already exists is an amendment — that belongs to
  `/feature-spec`, which offers amend / restart / read-only
