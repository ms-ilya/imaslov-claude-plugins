# Critic rubric

Passed **inline** to the critic — it runs in fresh context and cannot open this
file. Three lenses, run in order, every finding labelled with its lens.

The critic judges **the writing**, not the imagined implementation. Every check
below is a yes/no with a stated failure. That is what stops the pass degrading
into taste.

## Contents
- Lens 1 — Completeness
- Lens 2 — Consistency
- Lens 3 — Principles
- Blocking versus advisory
- Discipline
- The anti-rubber-stamp rule
- Output
- Confidence, calibrated

## Lens 1 — Completeness

Run as tests. Each fails loudly or passes; there is no middle.

| Check | Fails when |
|---|---|
| Every category not `Missing` in the coverage table has at least one requirement tracing to it | a `Clear` category has no requirement — that is a scoring error, not a gap |
| Every requirement has an acceptance scenario | any `FR` has none |
| Every success criterion names the number that would prove it | you cannot state the number |
| Every requirement and criterion carries a **valid** source tag | any is untagged, or tagged with something not in the valid list → **blocking** |
| Every P1 story is independently testable, and **P1 alone is a shippable slice** | P1 needs P2 to be useful → the priorities are wrong |
| No unquantified adjective survives outside a quoted user goal | "fast", "robust", "seamless", "intuitive" appear as requirements |
| Identifiers are not renumbered from the previous draft | any `FR`/`SC` number has moved → **blocking**, it is silent damage |

## Lens 2 — Consistency

Do the requirements contradict **each other**, the chosen strategy, or a promoted
ADR? Is a term used that the glossary does not define, or defined differently
from how the glossary defines it?

Contradicting a promoted ADR is blocking. An undefined term is advisory unless a
requirement's meaning depends on which reading is taken — then it is blocking.

## Lens 3 — Principles

Does the spec violate a line in the project's own stated rules?

The rules arrive verbatim in the packet. **Enforce those words, never your own
taste.** A rule the project did not state is not a finding, however sound.

Three outcomes, and the middle one is the valuable artifact:

| Outcome | Verdict |
|---|---|
| Complies | nothing — silence is the pass |
| Deviates, and the spec carries a justified deviation row | not a finding. Check the justification names what was considered instead. |
| Deviates, unjustified | **blocking** |

## Blocking versus advisory

> **Blocking if shipping the spec as written would cause someone to build the
> wrong thing, or if the spec asserts something the interview never decided.
> Everything else is advisory.**

| ✗ Should not have blocked | ✓ Blocking |
|---|---|
| "The wording of FR-003 is awkward." — style, advisory at most | "FR-003 requires an offline mode; the chosen strategy assumes a live connection." — contradicts the strategy |
| "Consider adding a `--verbose` flag." — a new idea, not a defect | "SC-002 has no source tag." — asserted without a decision behind it |

**A deliberate gap is not a defect.** The packet carries the coverage table and
the deferred list precisely so that a `[NEEDS CLARIFICATION]` marker reads as a
recorded decision rather than an omission. Flagging one as incomplete is a
misread of the packet, not a finding.

## Discipline

- **Verbatim citation.** Every finding quotes the exact text it is about. A
  paraphrase is a finding nobody can check.

  | ✗ Paraphrase | ✓ Verbatim |
  |---|---|
  | "The spec says retries should be reasonably fast." | QUOTE: "retries complete promptly" — no number, and no settled answer gives one |

- **Forced verdict.** `ship` or `fix-first`, with calibrated confidence. "It
  depends" is useless from a critic.
- **Declared blind spot.** State what this pass could not assess. Honest scope
  beats false completeness.
- **No empty diplomacy.** No "great work", no hedging preamble. Direct language.
- **Nothing fabricated.** No invented examples, numbers or file paths.
- **Verify, do not explore.** Open a file only to check a path the draft cites.

## The anti-rubber-stamp rule

A critic returning nothing is the failure mode, exactly as a debate where
everyone agrees is a failed debate.

> **If nothing is blocking, list what was specifically checked and found sound,
> citing verbatim. "Looks good" is not a valid return.**

| ✗ Rubber stamp | ✓ Sound |
|---|---|
| "No issues found. The spec is well written." | "Checked: all 9 requirements carry source tags resolving to settled answers; SC-001 names 500ms; P1 (FR-001–003) is shippable without P2." |

## Output

```skeleton
VERDICT: ship | fix-first
CONFIDENCE: high | moderate | low — <one sentence saying why>
BLIND SPOT: <what this pass could not assess>

BLOCKING
- B1 [completeness] FR-004 — <finding>
  QUOTE: "<verbatim from the draft>"
  WHY: <one sentence>
  FIX: <the smallest edit that would clear this>

ADVISORY
- A1 [consistency] SC-002 — <finding> — QUOTE: "..."

COULD NOT VERIFY
- <claim needing a human or a running build to confirm>

CHECKED AND SOUND
- <required when BLOCKING is empty>
```

**Every finding carries an ID and a target, and this is load-bearing.** Exactly
one re-run is allowed, so the second pass must be able to report per finding:
`B1 fixed · B2 not fixed · B3 new`. Without IDs that reconciliation is prose, and
the critique file cannot say precisely what shipped unresolved.

**Severity is the section, not the prefix.** A finding is blocking because it
sits under `BLOCKING`, and `check-critique.sh` reads it that way — so the id is
free to be whatever keeps it unique. Put every finding under one of the two
headings; one written outside them cannot be classified, and a finding nobody
can classify ships as resolved.

**Running as one of three parallel lenses?** Your packet names the prefix to use
— `BC`/`AC` for completeness, `BS`/`AS` for consistency, `BP`/`AP` for
principles. Three lenses sharing one numbering means two different findings
called `B1`, and only one of them can be reported on.

**`FIX:` exists for the same reason.** There is one attempt. A finding that does
not say what would clear it wastes it.

## Confidence, calibrated

| Level | Means |
|---|---|
| **high** | Every check ran against text that was in the packet |
| **moderate** | A check depended on something the packet only summarised |
| **low** | A lens could not run — say which, and put it in the blind spot |
