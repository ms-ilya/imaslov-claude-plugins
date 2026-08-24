# Spec template

A skeleton with slot descriptions. **What goes in each section is fixed; what it
says is not.** Every section below has a job; a section with nothing to say is
deleted, not padded.

The spec is read by a person and by an agent. That is what the stable identifiers
and the source tags are for, and it is why they cost one line each.

## Contents
- Sections
- Slot rules
- A requirement states behaviour, not implementation
- A success criterion names its number
- Source tags — every FR, SC and scenario
- Identifiers are stable
- What the spec never contains

## Sections

```skeleton
# <Feature name>

<One paragraph: whose problem, what changes for them. From ## Problem.>

## User stories

P1 · <story title>
  <One or two sentences. P1 alone must be a shippable slice.>
P2 · <story title>
P3 · <story title>

## Requirements

FR-001  <One testable statement of behaviour.>
        ← <source tag>

## Success criteria

SC-001  <One measurable outcome, with the number in it.>
        ← <source tag>

## Acceptance scenarios

FR-001  Given <state>, when <action>, then <observable result>.

## Out of scope

- <What this deliberately does not do, and why.>

## Chosen approach

<The strategy, in three sentences. Then the rejected ones with their reasons.>

## Principle deviations

| Rule, quoted verbatim | Why this feature breaks it | What was considered instead |

## Clarifications

- Q<n> (r<n>) — <question> → <answer>

## Open questions

- [NEEDS CLARIFICATION: <what was deferred, and why>]
```

## Slot rules

| Section | Rule |
|---|---|
| Opening paragraph | From the record's `## Problem` line, expanded. Never invented — if the record has no problem statement, the spec says so. |
| User stories | Priorities come from the record's `[P1]`/`[P2]`/`[P3]` tags. **Never assigned at drafting time.** **P1 alone must be shippable**: if P1 needs P2 to be useful, the priorities are wrong and that is a finding. |
| Requirements | One behaviour each. Numbered, tagged, testable. |
| Success criteria | One measurable outcome each, with the number present. |
| Acceptance scenarios | Given/When/Then. **Every `FR` has at least one.** |
| Out of scope | From settled scope-boundary answers. An empty section means nobody asked; say that rather than deleting it. |
| Chosen approach | Chosen **and rejected**, with reasons. Omit the section entirely when the strategy phase was skipped, and say it was skipped. |
| Principle deviations | Omit when there are none — silence is the pass. |
| Clarifications | One line per settled question, **every run**, not only on amendment. The rationale stays in the record; this is the index into it. |
| Open questions | Every deferred item, as a marker. Never quietly dropped. |

## A requirement states behaviour, not implementation

> **If the sentence names a type, a library or a function, it is a design note.
> Move it to the chosen-approach section or cut it.**

| ✗ Implementation | ✓ Behaviour |
|---|---|
| "Use a bloom filter to dedupe incoming rows." | "A row already ingested is not ingested twice, and the check does not require a full table scan." |
| "Add a `--json` flag that calls the JSON encoder." | "Output is machine-readable on request, and the machine-readable form is stable across versions." |

## A success criterion names its number

> **A criterion passes if you can state the number that would prove it. Cannot
> name the number → it fails.**

| ✗ Cannot name the number | ✓ Names it |
|---|---|
| "The list scrolls smoothly." | "The list holds 60fps while scrolling 1,000 rows on the oldest supported device." |
| "Retries do not overload the endpoint." | "No endpoint receives more than 1 retry per 30s regardless of backlog depth." |

A criterion whose number the interview never settled is **not** written with an
invented number. It is written as an open question.

**Write the number as digits.** `in all 3 cases`, not `in all three cases`. A
criterion is checked by comparing against a value, and a reader who has to parse
English to find that value will eventually parse it differently. `check-spec.sh`
warns on a criterion that names no digit.

## Source tags — every FR, SC and scenario

Every requirement, success criterion and acceptance scenario carries a tag naming
where in the record it came from.

Valid sources, and nothing else:

`Settled Q<n>` · `Grounding fact <n>` · `Strategy (chosen)` ·
`Principle: <file>` · `ADR-<id>` · a file named in the record's `## Reads`

| ✗ Not a source | ✓ A source |
|---|---|
| `← industry standard` | `← Settled Q4 (r2)` |
| `← discussed in the interview` — no line to check | `← Grounding fact 2` |
| `← Deferred Q8` — a deferral is not a decision | `← Settled Q2 (r1), Grounding fact 7` |

**A tag may name several sources, comma separated**, and every one of them is
resolved — a citation in second position is a citation. The plural reads
naturally where it should: `← Grounding facts 15, 41` and `← Settled Q2, Q9` each
name two, the second borrowing its noun from the first.

**A statement with no valid source is cut, or kept and marked
`[NEEDS CLARIFICATION: not decided in the interview]`. It is never asserted.**

This is the enforceable form of "draft from the record, not from the
conversation": an input prohibition cannot be checked, an output property can.
The critic treats an untagged requirement as blocking.

## Identifiers are stable

`FR-NNN` and `SC-NNN` are what make the spec addressable. An identifier that
renumbers on a re-draft breaks the thing it exists for.

- Assigned in draft order. **Never reused, never renumbered.**
- A withdrawn requirement stays in place as
  `FR-007 (withdrawn — see Clarifications)`. Not deleted, number not recycled.
- A split becomes `FR-007a` / `FR-007b`. The parent number survives.
- An amendment continues the sequence; it never restarts it.

The critic flags a renumber as blocking — it is silent damage otherwise.

## What the spec never contains

No implementation plan, no task breakdown, no file-by-file change list, no
estimates. The spec stops at what and why. How is somebody else's document, and
mixing them produces a spec that is obsolete the first time the plan changes.
