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
- `/feature-spec-write --from-tree <path> [--out <dir>]` — draft from any design
  record, including one this project's interview did not produce

**If no arguments are provided:** list the slugs that have a design record but no
spec, and ask which one.

## Key reminders

- Runs in a **forked context** (`context: fork`) — it reads the design record and
  the files that record names, and nothing else. Your conversation history is not
  visible to it, which is what stops a half-remembered interview leaking into the
  spec
- **It cannot ask you anything.** With no arguments it lists the slugs that have a
  record but no spec, and stops; you re-invoke with the one you want
- Every requirement and success criterion carries a source tag; anything
  untraceable is cut or marked, never asserted
- A slug whose spec already exists is an amendment — that belongs to
  `/feature-spec`, which offers amend / restart / read-only
