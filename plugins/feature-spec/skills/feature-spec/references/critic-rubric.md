# Critic rubric

Passed to the critic inside its packet — it runs in fresh context and never
loads this file itself. Three lenses, run in order, every finding labelled with
its lens.

The critic judges **the writing**, not the imagined implementation. Every check
below is a yes/no with a stated failure. That is what stops the pass degrading
into taste.

`check-spec.sh` has already passed on the draft: every tag resolves to an entry
of the record, every requirement has a scenario keyed to it, every out-of-scope
line and constraint is tagged, and no identifier moved. Those are not re-checked
here. The lenses are what a script cannot judge.

## Lens 1 — Completeness

Run as tests. Each fails loudly or passes; there is no middle.

| Check | Fails when |
|---|---|
| Every category scored `Clear` or `Clear*` shows up in the spec: a requirement, criterion, scope line or constraint is about it. `N/A` rows and Vocabulary are exempt | a category is scored Clear and the spec says nothing about it — a scoring error, not a gap |
| Every acceptance scenario tests the requirement it is keyed to | a scenario restates its requirement, tests something the requirement does not say, or covers one case of a requirement that states several |
| Every success criterion names the number that would prove it | you cannot state the number |
| The user stories are in the packet. Every P1 story is independently testable, and **P1 alone is a shippable slice**. When the stories carry no priority, the check does not run: say so | P1 needs P2 to be useful → the priorities are wrong |
| No unquantified adjective survives outside a quoted user goal. The script matches a fixed word list; the test is whether you could state the number | "fast", "robust", "seamless", "intuitive" or their kind appear as requirements |
| The packet lists what the record decided or found and no statement cites. Each such decision is one the spec has no need to state: a priority, who the feature is for | a decision about behaviour the user will see sits in that list — the spec left it out |

## Lens 2 — Consistency

**Does each statement say what its source says?** The packet prints the text of
every decision and grounding fact the tags cite, directly under the statements.
Compare them. A requirement that adds a number, a condition or a case its source
does not contain asserts something nobody decided, and that is blocking. So is a
requirement that follows the claim in a fact graded `contradicted` instead of
what the code was found to do.

The opening paragraph and the user stories carry no tags. They may summarise the
tagged statements. A claim in either that no tagged statement makes is blocking.

Do the requirements contradict each other, the chosen strategy, a promoted ADR,
or an implementation constraint the user fixed? Contradicting a promoted ADR is
blocking. The spec's own account of the approach is printed under the record's
strategy: it names the same chosen and rejected approaches, for the same
reasons.

Is a term used differently from its glossary entry? The packet lists the entries
this feature wrote. An undefined term is advisory unless a requirement's meaning
depends on which reading is taken — then it is blocking.

## Lens 3 — Principles

Does the spec violate a line in the project's own stated rules?

The rules arrive verbatim in the packet, and so does every deviation the spec
declares. **Enforce those words, never your own taste.** A rule the project did
not state is not a finding, however sound.

Three outcomes, and the middle one is the valuable artifact:

| Outcome | Verdict |
|---|---|
| Complies | nothing — silence is the pass |
| Deviates, and the spec carries a justified deviation row | not a finding. Check the justification names what was considered instead. |
| Deviates, unjustified | **blocking** |

## Blocking versus advisory

> **Blocking if shipping the spec as written would cause someone to build the
> wrong thing, or if the spec asserts something nobody decided. Everything else
> is advisory.**

| ✗ Should not have blocked | ✓ Blocking |
|---|---|
| "The wording of FR-003 is awkward." — style, advisory at most | "FR-003 requires an offline mode; the chosen strategy assumes a live connection." — contradicts the strategy |
| "Consider adding a `--verbose` flag." — a new idea, not a defect | "FR-006 stops retrying after 3 attempts; Settled Q2, which it cites, says at most 5." — says what its source does not |

**A deliberate gap is not a defect.** The packet carries the coverage table and
the deferred list precisely so that a `[NEEDS CLARIFICATION]` marker reads as a
recorded decision rather than an omission. A `Clear*` category was cleared by
bounded deferral; it is not a `Clear` category with a mistake in it. Flagging
either as incomplete is a misread of the packet, not a finding.

## Discipline

- **Verbatim citation.** Every finding quotes the exact text it is about, copied
  from the packet. A paraphrase is a finding nobody can check. A script compares
  each quote with the packet and discards a finding whose quote is not there.

  | ✗ Paraphrase | ✓ Verbatim |
  |---|---|
  | "The spec says retries should be reasonably fast." | QUOTE: "retries complete promptly" — no number, and no settled answer gives one |

- **Forced verdict.** `ship` or `fix-first`, with calibrated confidence. "It
  depends" is useless from a critic.
- **Declared blind spot.** State what this pass could not assess, or `none`.
  Honest scope beats false completeness.
- **No check without its input.** When the packet does not carry what a check
  needs, the check goes under `COULD NOT VERIFY`. It is never reported as passed.
- **No empty diplomacy.** No "great work", no hedging preamble. Direct language.
- **Nothing fabricated.** No invented examples, numbers or file paths.
- **Verify, do not explore.** Open a file only to check a `path:line` a grounding
  fact cites.

## The anti-rubber-stamp rule

A critic returning nothing is the failure mode, exactly as a debate where
everyone agrees is a failed debate.

> **If nothing is blocking, list what was specifically checked and found sound.
> Each item quotes the text or names the identifier it is about. "Looks good" is
> not a valid return.**

| ✗ Rubber stamp | ✓ Sound |
|---|---|
| "No issues found. The spec is well written." | "FR-002 "at most 5 times over 24 hours" says what Settled Q2 says, "at most 5 attempts spread over 24h"." · "SC-001 names its number, 500ms." · "P1 (FR-001 to FR-003) is shippable without P2." |

Equally, do not manufacture a blocking finding. There is one re-run; a fabricated
defect spends it and teaches the orchestrator to discount you. Advisory exists
for the real-but-not-blocking case.

## Output

Exactly this shape, nothing before or after it:

```skeleton
VERDICT: ship | fix-first
CONFIDENCE: high | moderate | low — <one sentence saying why>
BLIND SPOT: <what this pass could not assess, or none>

RECONCILIATION
- B1 fixed
- B2 not fixed — <why>

BLOCKING
- B1 [completeness] FR-004 — <finding>
  QUOTE: "<verbatim from the packet>"
  WHY: <one sentence>
  FIX: <the smallest edit that would clear this>

ADVISORY
- A1 [consistency] SC-002 — <finding> — QUOTE: "..."

COULD NOT VERIFY
- <a check the packet gave you no input for, or a claim needing a running build>

CHECKED AND SOUND
- <required when BLOCKING is empty: what you checked, quoting it or naming its identifier>
```

Leave out a section that has nothing in it. Two exceptions:

- `CHECKED AND SOUND` is required whenever `BLOCKING` is empty. Each item quotes
  the text it checked or names the identifier it is about. Two items at least.
- `RECONCILIATION` appears only on a second pass, when the packet carries the
  first pass's blocking findings. One line per id listed there, the disposition
  directly after the id: `fixed` or `not fixed`. A finding that is not fixed
  keeps the verdict at `fix-first`.

The verdict follows from the findings: `fix-first` when anything is blocking or
still not fixed, `ship` otherwise.

**Every finding carries an ID and a target.** One re-run is allowed, so the
second pass has to say per finding what became of it. Without ids that is prose,
and the critique cannot say precisely what shipped unresolved. An id is never
reused, under the other heading or on the second pass.

**Severity is the section, not the prefix.** A finding is blocking because it
sits under `BLOCKING`, and `check-critique.sh` reads it that way. Put every
finding under one of the two headings; one written outside them cannot be
classified.

**`FIX:` exists for the same reason.** There is one attempt. A finding that does
not say what would clear it wastes it.

## Confidence, calibrated

| Level | Means |
|---|---|
| **high** | Every check ran against text that was in the packet |
| **moderate** | A check depended on something the packet only summarised |
| **low** | A lens could not run — say which, and put it in the blind spot |
