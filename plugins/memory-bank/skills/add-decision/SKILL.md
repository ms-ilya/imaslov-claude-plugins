---
name: add-decision
description: >-
  Add a technical decision (ADR-style) to a feature's DECISIONS.md in the
  Memory Bank.
tools: Read, Write, Edit, Glob, Bash
---

# Add Decision to Memory Bank

You are recording a technical decision for a feature in the project's Memory Bank.

## Read the skill first

Read `../memory-bank/references/templates.md` — specifically the DECISIONS.md template for the ADR format.

## Action

Run **Workflow 4: Manual Decision** from `../memory-bank/SKILL.md`.

**Arguments format:** `<feature-name>: <decision description>`

Example: `/add-decision authentication: Use Keychain instead of UserDefaults for token storage`

Parse `$ARGUMENTS` to extract:
1. **Feature name** — everything before the first `:`
2. **Decision description** — everything after the `:`

If the format isn't clear, ask the user to clarify which feature and what was decided.

## Steps

1. Open `memory-bank/<feature-name>/DECISIONS.md`
2. If the feature folder doesn't exist, ask if the user wants to create it first with `/update-memory-bank <feature>`
3. Add a new ADR entry at the top (newest first)
4. Ask the user for any missing fields: rationale, alternatives considered, consequences
5. Append — never overwrite existing decisions. Mark superseded ones as "Superseded" if applicable.
