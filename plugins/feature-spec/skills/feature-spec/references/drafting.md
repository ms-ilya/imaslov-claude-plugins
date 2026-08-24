# Drafting, critique and report — phases 5 to 7

Loaded at Phase 5 by both `feature-spec` and `feature-spec-write`, which run the
same three phases and must run them identically.

It lives here rather than in either skill for two reasons. The orchestrator is
bounded by the compaction re-attach budget — only the head of a `SKILL.md` is
carried forward when the conversation is summarised — and these phases are the
ones the run needs *last*, so they are the ones most likely to be cut. And a
second copy in a second skill is a second thing to keep in step.

The input to everything below is `tree.md` and the files its `## Reads` names.
Nothing else.

---

## Phase 5 — DRAFT

Load `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/spec-template.md` — an instruction file, not content.

**Read `tree.md` and exactly the files in its `## Reads` list. Nothing else.** No
re-interview, no `## History`.

- Deferred items become inline `[NEEDS CLARIFICATION: ...]` markers.
- Priorities come from the record's `[P1]`/`[P2]`/`[P3]` tags. **Never assign one
  at drafting time** — that is a decision the user never made.
- Every requirement, criterion and scenario carries a source tag naming the
  `tree.md` line it came from. Anything untraceable is **cut or marked, never
  asserted** (R10).
- Identifiers are assigned in draft order and **never renumbered**. A withdrawn
  requirement stays in place as `(withdrawn)`; a split becomes `007a`/`007b`.
- A justified principle deviation gets a `## Principle deviations` row quoting
  the rule verbatim. Silence is the pass.

**Do not write `spec.md` yet.** Write the draft to `<specdir>/spec.draft.md`,
then fix until clean:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-spec.sh <specdir>/spec.draft.md --tree <specdir>/tree.md`

**`--tree` is required and the script refuses to run without it.** It resolves
every source tag against the record — `Settled Q7` must be a question the record
actually settled, `Grounding fact 3` an item that exists. A tag that is merely
*shaped* like a tag is the check a fabricated citation passes, so a tag that does
not resolve fails as a fabricated citation.

On an **amendment**, add `--prev <specdir>/spec.md`, which is what catches a
silent renumber. The script refuses a `--prev` it cannot read, so pass a real path
or omit the flag; never a placeholder. Reworded text under a stable identifier
**fails** — re-run with `--allow-reword` only once you have confirmed the edit is
deliberate, so the acknowledgement is recorded rather than assumed.

It enforces R10 mechanically — unresolved, untagged or invalid tags, duplicate or
vanished identifiers, requirements with no scenario, unquantified adjectives, bare
markers. These are not critic findings: fix them silently. **Delete
`spec.draft.md` once `spec.md` exists.**

## Phase 6 — CRITIQUE

Skipped in `--fast`.

**Build the packet with the script. Never by hand.**

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/make-packet.sh <specdir>/spec.draft.md --tree <specdir>/tree.md
```

It emits every part the critic needs — the requirement and criterion list with
source tags, the acceptance scenarios, the coverage table with `Clear*` marks
intact, the deferred list, chosen and rejected strategies, promoted ADR titles
**with their decisions**, the principle lines verbatim, the scope boundary, and
the rubric inline, because the agent cannot resolve a skill path.

A hand-rolled `sed` range is how a lens came to declare a blind spot it should
never have had: `## Out of scope` arrived as a heading with no content, and
scope compliance could not be checked against a boundary that never got there.
The script prints `_the spec states no scope boundary_` instead — an empty
section that says it is empty is checkable; a silently truncated one is not.

**Not the whole draft.** Passing prose sections doubles this phase's cost. If a
lens seems to need one, the packet is wrong.

In `--deep`, dispatch three agents in parallel, one per lens, and route the
principles lens to `model: opus`. **Give each its own packet** —
`--lens completeness`, `--lens consistency`, `--lens principles` — which carries
only that lens's rubric and assigns it a distinct finding-id prefix (`BC`/`AC`,
`BS`/`AS`, `BP`/`AP`). Three agents all numbering their findings `B1` cannot be
reconciled per finding in the second pass, which is the whole point of the ids.

Save each pass verbatim and validate it — the anti-rubber-stamp rule and the
`QUOTE:`/`FIX:` discipline are checkable, not matters of impression:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-critique.sh <pass1.txt> --single`

Blocking findings → fix, re-run **once**. Then reconcile the two passes with the
script, which asserts every pass-1 id is accounted for:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-critique.sh <pass1.txt> <pass2.txt>`

A finding that vanishes between passes otherwise ships as resolved. **Then write
regardless** (R12).

Write `spec.md`, the final `tree.md`, and `critique.md` with any unresolved IDs.

## Phase 7 — REPORT

Flip every ADR this run proposed to `Status: Accepted` — the spec now exists.

Generate the two derived artifacts. Both read the spec and the record, so neither
can drift from what it summarises, and neither costs an interview token:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/make-traceability.sh <specdir>/spec.md --tree <specdir>/tree.md
```

`traceability.md` joins every requirement to the question, answer, reasoning and
round behind it — and lists any answer the user gave that no requirement cites,
which is worth reading before you report. **It exits non-zero on an untraceable
requirement**, so it is a check as well as an artifact.

If the user wants a one-page summary for an issue, write it inline. A script for
that would establish no property the spec does not already carry, and every
script is one more thing to remember.

Report: paths · the coverage table with deferral counts · deferred items ·
ADRs written · glossary terms · critic verdict and confidence.

If the project keeps a `memory-bank/`, say in one line that this spec is ready to
document once the feature ships, and name `/update-memory-bank`. A suggestion,
never a call — the same stance taken with `/multi-agent-debate`.

Say in one line that `/feature-spec-plan <slug>` turns this spec into an
implementation plan. **A suggestion, never a call, and never mentioned before
this point.** The interview must not know a plan follows it: a spec written as a
gate on the way to code gets optimised to be passed rather than to be good, which
is the failure this whole plugin is built around. Phase 7 is after every question
has been asked, so naming it here costs nothing.

**Counted cost, never estimated** (R6, R11): rounds used of cap · questions
asked · fact-finder dispatches · reference files loaded · critic passes.

When more than a third of categories ended `Clear*`, say so plainly: *"most of
this spec is open questions — consider another round, or a narrower feature."*
