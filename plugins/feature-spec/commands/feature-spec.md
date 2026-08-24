---
description: Bounded requirements interview that ends in a critic-verified feature spec.
---

# Feature Spec

Run the full pipeline: ground in the repo, interview in capped rounds tracked
against a coverage taxonomy, choose a strategy, promote hard-to-reverse
decisions, then draft, critique and write the spec.

## Read the skill first

Before doing anything, read `SKILL.md` from the `feature-spec` skill in the
feature-spec plugin, and follow it exactly.

## Action

Run phases 0 through 7 from that SKILL.md.

**Arguments:** `$ARGUMENTS`

Usage:
- `/feature-spec <idea>` — default mode, up to 3 rounds
- `/feature-spec <idea> --fast` — one round, no critic, ~5 minutes
- `/feature-spec <idea> --deep` — up to 5 rounds, strategy always, critic panel
- `/feature-spec <slug> --resume` — continue an interview that never finished
- `/feature-spec <idea> --scope <path>` — confine grounding to one directory
- `/feature-spec --prior-art <doc.md>` — the input is an existing analysis
  document; Phase 1's job becomes verifying its claims against the code

**If no arguments are provided:** list the existing spec slugs, ask for a feature
idea, and stop. Do not start an interview on an unformed idea.

## Key reminders

- `--fast` and `--deep` together is an error — do not guess which was meant
- Writes only inside the spec directory, plus the ADR directory
- Running on an existing slug offers amend / restart / read-only, never a
  silent overwrite
- Produces `spec.md`, `tree.md` and `critique.md`; all three are meant to be
  committed
