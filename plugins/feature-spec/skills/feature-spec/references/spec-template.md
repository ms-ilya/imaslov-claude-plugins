# Spec template

A skeleton with slot descriptions. **What goes in each section is fixed; what it
says is not.** Every section below has a job. A section with nothing to say is
left out, not padded; the one exception is Out of scope, which stays and says
that nobody asked. No other heading is added: a statement under a section this
template does not define is checked by nothing, and `check-spec.sh` fails it.

The spec is read by a person and by an agent. That is what the stable identifiers
and the source tags are for, and it is why they cost one line each.

## Contents
- Sections
- Slot rules
- A requirement states behaviour, not implementation
- A success criterion names its number
- Source tags
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

- <What this deliberately does not do, and why.> ← <source tag>

## Implementation constraints

- <A decision about how, made by the user before drafting.> ← <source tag>

## Chosen approach

<The strategy, in three sentences. Then the rejected ones with their reasons.>

## Principle deviations

| Rule, quoted verbatim | Why this feature breaks it | What was considered instead |

## Clarifications

- Q<n> (r<n>) — <question> → <answer>

## Open questions

- [NEEDS CLARIFICATION: Q<n> — <what was deferred, and why>]
```

## Slot rules

| Section | Rule |
|---|---|
| Opening paragraph | The record's `## Problem` line, and at most a sentence or two that summarise the tagged statements below. It carries no tag, so it says nothing they do not. If the record has no problem statement, the spec says so. |
| User stories | Priorities come from the record's `[P1]`/`[P2]`/`[P3]` tags. **Never assigned at drafting time.** When the record ranks nothing, write the stories with no `P<n>` and leave the ranking as the open question the record defers. **P1 alone must be shippable**: if P1 needs P2 to be useful, the priorities are wrong and that is a finding. Like the opening paragraph, a story says nothing the tagged statements do not. |
| Requirements | One behaviour each. Numbered, tagged, testable. A long statement continues on indented lines under its identifier; every other line in the section belongs to an identifier or is a finding. |
| Success criteria | One measurable outcome each, with the number present. |
| Acceptance scenarios | Given/When/Then. **Every `FR` has at least one.** |
| Out of scope | From settled scope-boundary answers, each line tagged with the decision it came from. An empty section means nobody asked; say that rather than deleting it. |
| Implementation constraints | Only what the **user** decided about *how*: a library, where the code lives, a pattern to follow. Each line tagged. The spec does not argue for them; it records them so a plan takes them as given instead of presenting them as its own assumptions. Omit when there are none. Never a place for a design the drafter prefers. |
| Chosen approach | Chosen **and rejected**, with reasons. Omit the section entirely when the strategy phase was skipped; the final report says it was. |
| Principle deviations | Omit when there are none — silence is the pass. |
| Clarifications | One line per `## Settled` entry, **every run**, copied from the record: id, round, title and answer as written there. An `(r0)` entry was never asked, so its title stands where a question would. The rationale stays in the record; this is the index into it. |
| Open questions | Every deferred item, as a marker that opens with its question id. **Once, and here.** A requirement that depends on one says so in words and names the id; it does not repeat the marker, because every marker is counted and carried into the plan as its own question. Never quietly dropped. |

## A requirement states behaviour, not implementation

> **If the sentence names a type, a library or a function, it is a design note.
> If the user decided it, it goes under Implementation constraints with its tag.
> If the strategy phase chose it, it goes in the chosen-approach section.
> Otherwise cut it.**

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

## Source tags

Every requirement and success criterion carries a tag naming where in the record
it came from. So does every out-of-scope line and every implementation
constraint: each is a decision too. An acceptance scenario is keyed by the
requirement it tests and takes that requirement's sources; it carries no tag of
its own.

Valid sources, and nothing else:

`Settled Q<n>` · `Grounding fact <n>` · `Strategy (chosen)` ·
`Principle: <file>` · `ADR-<id>`

`Principle:` names a principles file the record reads. `ADR-<id>` names an ADR
file in `## Reads` by its leading number (`ADR-0004`), or by its whole file name
without the extension when the file is not numbered.

| ✗ Not a source | ✓ A source |
|---|---|
| `← industry standard` | `← Settled Q4 (r2)` |
| `← discussed in the interview` — no line to check | `← Grounding fact 2` |
| `← Deferred Q8` — a deferral is not a decision | `← Settled Q2 (r1), Grounding fact 7` |
| `← docs/briefs/retry.md` — a file is where a decision came from, not a decision | `← Settled Q1 (r0)` — the entry intake wrote from that brief |
| `← Grounding fact 5`, when fact 5 is graded `unverifiable` — not a fact | the open question that claim became |

**A tag may name several sources, comma separated**, and every one of them is
resolved — a citation in second position is a citation. The plural reads
naturally where it should: `← Grounding facts 15, 41` and `← Settled Q2, Q9` each
name two, the second borrowing its noun from the first.

**A statement with no valid source is cut, or kept and marked
`[NEEDS CLARIFICATION: not decided]` in place. It is never asserted.** That
inline marker is for a statement nobody decided. A question the record deferred
is marked once, under Open questions.

This is the enforceable form of "draft from the record, not from the
conversation": an input prohibition cannot be checked, an output property can.
`check-spec.sh` fails an untagged statement; whether a tagged one says what its
source says is the critic's to judge.

## Identifiers are stable

`FR-NNN` and `SC-NNN` are what make the spec addressable. An identifier that
renumbers on a re-draft breaks the thing it exists for.

- Assigned in draft order. **Never reused, never renumbered.**
- A withdrawn requirement stays in place as
  `FR-007 (withdrawn — see Clarifications)`. Not deleted, number not recycled.
- A split becomes `FR-007a` / `FR-007b`. The parent number survives.
- An amendment continues the sequence; it never restarts it.

`check-spec.sh --prev` fails a renumber on an amendment — it is silent damage
otherwise.

## What the spec never contains

No implementation plan, no task breakdown, no file-by-file change list, no
estimates. The spec stops at what and why. How is somebody else's document, and
mixing them produces a spec that is obsolete the first time the plan changes.
