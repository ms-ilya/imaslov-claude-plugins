# ADRs

An architecture decision record is for a decision someone will otherwise
re-litigate. **Over-production is the known failure mode** — a directory with
thirty entries is a directory nobody reads, which is the same as no ADRs with
extra steps.

So the bar is high, it is a procedure, and most decisions fail it.

## Contents
- The three-part test
- Negative examples first
- Where ADRs go
- Status lifecycle
- Format
- What an ADR is not

## The three-part test

> **Hard to reverse? AND surprising without context? AND the result of a real
> trade-off? Failing any one means no ADR.**

| Test | Fails when |
|---|---|
| **Hard to reverse** | changing it later is a one-line edit, or touches only code nobody outside the team calls |
| **Surprising without context** | it is the obvious default, the framework's own recommendation, or what every sibling module already does |
| **The result of a real trade-off** | nothing was given up. If you cannot name what the rejected option was better at, there was no trade-off |

## Negative examples first

Most candidates fail, so calibrate on failures:

| ✗ No ADR — and which test it fails | ✓ ADR |
|---|---|
| "Exit code 2 for a config error" — fails **hard to reverse**: it is one line | "The tool writes its checkpoint to the working directory rather than a user cache dir" — irreversible for anyone scripting it, surprising, and traded portability for scriptability |
| "Use the framework's built-in router" — fails **surprising**: it is the obvious default | "Deliveries are at-least-once and consumers must dedupe" — hard to reverse once integrators depend on it, genuinely surprising, and traded consumer effort against a distributed transaction |
| "Index the timestamp column" — fails **a real trade-off**: nothing was given up | "Rejected rows are retained for 30 days rather than dropped" — traded storage against recoverability, and reversing it destroys data |

**A typical interview promotes zero or one decision.** Two is unusual. Three
means the test is being applied loosely — re-read the failure column above.

**The strategy choice is not automatically an ADR.** It is a decision with
rejected alternatives, which satisfies one test out of three. Run all three.

## Where ADRs go

The spec directory is the only directory this plugin owns — ADRs are the single
exception, because an ADR nobody can find at the conventional path is not an ADR.
The exception is paid for with three rules:

| Situation | Behaviour |
|---|---|
| An ADR directory exists using `NNNN-` names | Follow it: scan for the highest number, add one. This races across concurrent branches. Accepted, and noted in the README. |
| An ADR directory exists with any other naming | Match whatever is there. Never impose a scheme on a directory you did not create. |
| No ADR directory exists | Create `docs/adr/` and use **`YYYY-MM-DD-<slug>.md`**. Date prefixes do not race, and there is no convention to honour. |

## Status lifecycle

Every ADR is written `Status: Proposed` with a back-link to the design record,
and flipped to `Status: Accepted` only once the spec file exists.

A run abandoned between the two leaves a **proposed** decision with a live link
to the tree that produced it — self-documenting rather than orphaned. That is the
whole reason for the two states.

Never write `Status: Accepted` directly. The proposed state is what makes an
abandoned run legible.

## Format

```skeleton
# Retention of rejected rows

Status: Proposed
Date: 2026-08-21
Spec: docs/specs/2026-08-21-csv-resume/
Decided: Q9 (r2)

## Context

Rows that fail validation were discarded. Operators recovering from a bad source
file had no way to see what was dropped, and re-running the import re-dropped it.

## Decision

Rejected rows are written to a reject table and retained for 30 days.

## Consequences

Storage grows with failure volume rather than success volume, which is the
opposite of the usual assumption and needs a monitor. Recovery becomes possible
without the original file. Reversing this destroys data that operators will by
then depend on.

## Rejected

- Drop rejected rows, log a count — no recovery path, and the count is not
  actionable at 3am.
- Retain forever — unbounded growth on a table nobody prunes.
```

Six fields. `Decided:` and `Spec:` are the two that a template usually omits and
that make the record traceable back to the interview that produced it.

**`## Rejected` is not optional.** It is the field that satisfies the third test,
and an ADR without it is a decision announcement.

## What an ADR is not

- **Not a design document.** No code, no schema, no interface. If it names a
  function signature, it has become a design note.
- **Not a summary of the spec.** It records one decision, not the feature.
- **Not a place to relocate an unresolved question.** An open question ships as a
  clarification marker in the spec. Writing it as an ADR with a hedged decision
  turns an honest gap into a false record.
