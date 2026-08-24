# Task slicing

How a verified spec becomes an ordered set of tasks. Loaded at Phase 8, once.

The spec already settled *what* and *why*. This file is about the only question
left: **where do the cuts go, and in what order.**

## Contents
- The cut is a behaviour, not a layer
- How many tasks
- Ordering: dependency, then risk
- Milestones come from the spec's priorities
- Sizing a task
- What is not a task
- Where the material comes from

## The cut is a behaviour, not a layer

The default instinct is to slice by layer — one task for the model, one for the
store, one for the UI — because that is how the code is organised. It produces a
plan where nothing works until the last task lands, every task is unverifiable on
its own, and a half-finished plan is worth nothing.

Cut by **observable behaviour** instead. Each task should end with something that
is true from outside the code, and the spec has already written that something
down as an acceptance scenario.

| ✗ Sliced by layer | ✓ Sliced by behaviour |
|---|---|
| T01 add the model · T02 add the store · T03 wire the view | T01 attempt state survives a restart · T02 an interrupted import resumes · T03 a row that has failed 5 times is rejected |

The test: **can you state this task's done-condition by quoting a scenario from
the spec?** If not, the cut is in the wrong place — either it is a layer, or it
is enabling work that should be labelled as such.

## How many tasks

Driven by the requirement count and their dependencies, never by a target.

| Spec size | Usually |
|---|---|
| 1–3 requirements | 1–2 tasks |
| 4–8 requirements | 3–5 tasks |
| 9+ requirements, or several independent surfaces | 5+ tasks, and ask whether the feature should have been split |

**Two failure directions, both real.** One task per requirement, mechanically, is
over-decomposition: it produces a plan where three tasks all touch one function
and none can land alone. One task for the whole feature is under-decomposition:
it produces a plan that says nothing the spec did not already say.

Prefer merging two tasks that touch the same seam over keeping them separate for
symmetry. **Prefer splitting a task whose done-condition needs the word "and".**

## Ordering: dependency, then risk

1. **Hard dependencies first.** A task that writes state comes before the task
   that reads it. These are facts, not preferences, and they set the skeleton.
2. **Then the risky one, as early as its dependencies allow.** The task most
   likely to invalidate the approach should land while there is still room to
   change the approach. A plan that saves the unknown for last is a plan that
   discovers it is wrong at the end.
3. **Then everything else,** in whatever order keeps each milestone shippable.

Risk is legible from the record: an answer with a thin rationale, a grounding
fact at `medium` or `low` confidence, or a requirement whose source tag traces to
a strategy decision rather than a settled question. Those are the parts the
interview was least sure about.

## Milestones come from the spec's priorities

The spec's stories carry `P1`, `P2`, `P3`, and the spec guarantees **P1 alone is
a shippable slice**. So the milestone boundaries are already decided:

- **M1** — every task covering a P1 requirement, and **nothing else**.
- **M2** — P2. **M3** — P3.

A first milestone that reaches into P2 has thrown away the one guarantee the
interview bought. If M1 genuinely cannot ship without a P2 requirement, that is
not a milestone problem — it is a finding about the spec's priorities, and it
belongs in the report rather than being silently fixed here.

Enabling work joins the earliest milestone that needs it.

## Sizing a task

There is no hour estimate anywhere in this plugin — the interview never asked for
one, so any number here would be invented (R11). Size is expressed structurally:

- **One seam.** A task touching four unrelated files is usually two tasks.
- **One done-condition.** Two scenarios that can pass independently are two tasks.
- **Reviewable as one change.** If the diff would need its own summary to be
  reviewable, it is too big.

Where a task is genuinely large and will not split, say so in its `## Notes`
rather than pretending it is small.

## What is not a task

- **"Investigate X."** Investigation happened in the interview. If something is
  still unknown, it is an open question the spec should carry (R20), not a task.
- **"Write tests."** Tests belong inside the task whose behaviour they verify.
  A separate testing task is how testing becomes the thing that gets dropped.
- **"Refactor Y first."** Legal, but it is enabling work, and it is labelled as
  such with what it unblocks (R19). An unlabelled refactor is scope the user
  never approved.
- **"Update the docs."** Only when a requirement or criterion asks for it. If one
  does, it covers that identifier like anything else.

## Where the material comes from

Everything in the plan traces to something already written. Nothing here is an
invitation to re-decide.

| Plan element | Comes from |
|---|---|
| Task done-conditions | The spec's `## Acceptance scenarios` and `## Success criteria`, quoted |
| `Covers:` tags | The spec's `FR`/`SC` identifiers |
| Milestone boundaries | The spec's `P1`/`P2`/`P3` stories |
| `## Approach` | The spec's `## Chosen approach`, plus the ordering rationale |
| `Touches:` and `## Seams` | The record's `## Grounding facts` |
| Risk ordering | The record's confidence marks and thin rationales |
| Constraints on how | The record's `## Principles in force`, and any promoted ADR |
| `## Open questions` | The spec's `[NEEDS CLARIFICATION]` markers, copied intact |

**Anything with no row in that table is a plan assumption**, and it goes in
`## Plan assumptions` with its reversal cost (R21). That is not a discouragement
— a plan must make choices the spec refused to make. It is the requirement that
those choices are visible as choices.
