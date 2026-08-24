---
description: Turn a critic-verified feature spec into a checked implementation plan.
---

# Feature Spec — Plan

Cut a finished spec into ordered tasks with milestones, dependencies and
per-task done-conditions quoted from the spec, then have an independent critic
score the result.

## Read the skill first

Before doing anything, read `SKILL.md` from the `feature-spec-plan` skill in the
feature-spec plugin, and follow it exactly.

## Action

Run phases 8 through 11 against the spec for the given slug.

**Arguments:** `$ARGUMENTS`

Usage:
- `/feature-spec-plan <slug>` — slice, write, critique, report
- `/feature-spec-plan --from-spec <path> [--out <dir>]` — plan from any spec,
  including one this project's interview did not produce
- `/feature-spec-plan <slug> --tasks-only` — regenerate the task files against
  an existing `plan.md`, after the spec was amended

**If no arguments are provided:** list the slugs that have a spec but no plan,
and stop.

## Key reminders

- **It writes the plan and stops.** No code, no implementation, no estimates in
  hours or days — the interview never measured one
- Runs in a **forked context** (`context: fork`) — it reads the spec, the design
  record and the files that record names, and nothing else. It cannot ask you
  anything, so every path that would otherwise ask lists its options and stops
- **The spec is settled.** No re-grilling, no new requirements, no adjusting a
  priority. The only question left is where the cuts go and in what order
- Every task names the requirements it covers, and `check-plan.sh` proves the
  join in both directions: no fabricated identifier, and **no requirement
  silently dropped**
- Every implementation decision the spec did not settle is recorded under
  `## Plan assumptions` with what reversing it would cost
- An existing plan offers replan / extend / read-only, never a silent overwrite.
  After an amendment you almost always want **extend** — it keeps the statuses
  of work already done
- Produces `plan/plan.md`, `plan/tasks/T0N.md` and `plan/plan-critique.md`; all
  of it is meant to be committed
