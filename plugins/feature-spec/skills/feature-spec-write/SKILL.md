---
name: feature-spec-write
description: >-
  Drafts, critiques and writes a feature spec from an existing design record —
  phases 5 to 7. Runs in a fresh session with no memory of the interview. Use
  after /feature-spec-grill, or to draft a spec for a slug that has a design
  record but no spec yet.
argument-hint: "<slug>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
disable-model-invocation: true
---

# ABOUTME: Runs phases 5-7 of the feature-spec pipeline — draft, critique, write — from a design record alone.

You turn an existing design record into a written, critic-verified spec.

Self-contained: everything you need is below or in
`${CLAUDE_SKILL_DIR}/../feature-spec/references/`. Do not read another skill's `SKILL.md`.

**This command exists to be run in a fresh session**, with no memory of the
interview. That is not a limitation to work around — it is the property that
makes the design record worth writing.

## Critical rules

| ID | Rule |
|---|---|
| **R1** | **MUST** write every answer and its rationale to `tree.md` before rendering the next round, and before any other tool call. Answers arrive in batches, so the unit is the round, not the question. |
| **R2** | **MUST** find facts before a round, never during one. |
| **R3** | **MUST** announce the mode, the round cap and whether a 4th round can unlock, in Phase 0. |
| **R4** | **MUST** give every question a recommended answer and a one-line "why it matters" naming what the answer changes. |
| **R5** | **MUST** stop grilling and draft the moment the counter guard trips. |
| **R6** | **MUST** report counted cost when the run ends — rounds, questions, fact-finder dispatches, references loaded, critic passes. |
| **R7** | **MUST** update the `## Protocol` counters in `tree.md` at the end of every round, before anything else. |
| **R8** | **NEVER** ask the user something a fact-finder could look up. |
| **R9** | **NEVER** ask more than 5 questions in one round, or run more rounds than the mode allows. |
| **R10** | **NEVER** assert a statement in the spec that has no source tag in `tree.md`. Cut it, or mark it `[NEEDS CLARIFICATION]`. |
| **R11** | **NEVER** state a number you cannot count. Token spend, context percentage and elapsed cost are unobservable — reporting them is fabrication. |
| **R12** | **NEVER** block the deliverable on the critic. Two passes maximum, then write and attach the unresolved findings to `critique.md`. |
| **R13** | **NEVER** invent a rule the project did not state. The principles gate enforces the repo's rules, not your taste. |
| **R14** | **NEVER** write an ADR for a decision that fails any one of the three tests. |
| **R15** | **NEVER** silently overwrite an existing spec. Offer amend / restart / read-only. |
| **R16** | **NEVER** silently skip a phase. A skipped strategy phase is announced. |
| **R17** | **NEVER** write outside `<specdir>/`, except the ADR directory. Every other file in the repo is read-only to you. |

**R1–R9 govern the interview, which this stage does not run.** They are
reproduced verbatim so the three skills share one rule block; the rules you
can act on here are R10–R17.

## Track your progress

**Copy this checklist into your first reply and tick items as you go.**

```
feature-spec-write: <slug>
- [ ] Slug resolved by glob, record found and parseable
- [ ] tree.md + its ## Reads list read — nothing else
- [ ] Drafted, every FR/SC source-tagged            (R10)
- [ ] check-spec.sh clean
- [ ] Critic dispatched with the packet, not the draft
- [ ] Blocking findings fixed, at most one re-run    (R12)
- [ ] spec.md, tree.md, critique.md written
- [ ] ADRs flipped to Accepted
- [ ] Counted cost reported                          (R6, R11)
```

## Resolving the slug

`$ARGUMENTS` is a slug. Directories are date-prefixed, so **resolve by glob
`*-<slug>`**: one match proceeds; several are listed for the user to pick; none
means stop and list what exists.

No argument → list the slugs that have a design record but no spec, and ask.

**Stop and say so** if the record is missing or unparseable, or if `spec.md`
already exists. A spec already written is an **amendment**, which is
`/feature-spec`'s three-way choice — amend, restart or read-only — and not
something this command decides on its own (R15).

Load `${CLAUDE_SKILL_DIR}/../feature-spec/references/tree-format.md` if the record does not parse
cleanly, to report *which* section failed.

---

# Phases

## Phase 5 — DRAFT

Load `${CLAUDE_SKILL_DIR}/../feature-spec/references/spec-template.md` — an instruction file, not content.

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
`bash ${CLAUDE_SKILL_DIR}/../../scripts/check-spec.sh <specdir>/spec.draft.md`

On an **amendment**, pass the spec being replaced as a second argument —
`… <specdir>/spec.draft.md <specdir>/spec.md` — which is what catches a silent
renumber. The script refuses to run on a second argument it cannot read, so pass a
real path or none at all; never a placeholder.

It enforces R10 mechanically — untagged or invalid tags, duplicate or vanished
identifiers, requirements with no scenario, unquantified adjectives, bare
markers. These are not critic findings: fix them silently. **Delete
`spec.draft.md` once `spec.md` exists.**

## Phase 6 — CRITIQUE

**The critic always runs here.** This command takes no depth flag: invoking it is a
separate decision from however the interview was run, so a record grilled with
`--fast` still gets critiqued.

Dispatch `spec-critic` with the **critic packet inline**: the requirement and
criterion list with source tags, the acceptance scenarios, the coverage table
with `Clear*` marks intact, the deferred list, the chosen and rejected
strategies, promoted ADR titles with their one-line decisions, the principle
lines verbatim, and `${CLAUDE_SKILL_DIR}/../feature-spec/references/critic-rubric.md` **inline** — the agent cannot
resolve a skill path.

**Not the whole draft.** Passing prose sections doubles this phase's cost. If a
lens seems to need one, the packet is wrong.

In `--deep`, dispatch three agents in parallel, one per lens, and route the
principles lens to `model: opus`.

Blocking findings → fix, re-run **once**. The second pass reports an outcome per
finding ID (`B1 fixed · B2 not fixed · B3 new`). **Then write regardless** (R12).

Write `spec.md`, the final `tree.md`, and `critique.md` with any unresolved IDs.

## Phase 7 — REPORT

Flip every ADR this run proposed to `Status: Accepted` — the spec now exists.

Report: paths · the coverage table with deferral counts · deferred items ·
ADRs written · glossary terms · critic verdict and confidence.

**Counted cost, never estimated** (R6, R11): reference files loaded · critic
passes. Those are this run's. The interview's own totals — rounds, questions,
fact-finder dispatches — are **read** from the record's `## Protocol` block, so
report them as the record's, never as something this run counted.

When more than a third of categories ended `Clear*`, say so plainly: *"most of
this spec is open questions — consider another round, or a narrower feature."*

---

## Degradation

Load `${CLAUDE_SKILL_DIR}/../feature-spec/references/degradation.md` the moment you hit a failure
path. The rows that apply here: an unparseable record, a critic still blocking
after two passes, and an existing spec directory written by another tool.

## Reference loading

| File | Loaded at |
|---|---|
| `${CLAUDE_SKILL_DIR}/../feature-spec/references/spec-template.md` | Phase 5 |
| `${CLAUDE_SKILL_DIR}/../feature-spec/references/critic-rubric.md` | Phase 6 — **passed inline to the agent**, not loaded by you |
| `${CLAUDE_SKILL_DIR}/../feature-spec/references/tree-format.md` | only to diagnose an unparseable record |
| `${CLAUDE_SKILL_DIR}/../feature-spec/references/degradation.md` | on hitting a failure path |

## Scripts

Run this; do not reimplement its checks in prose.

| Script | When |
|---|---|
| `bash ${CLAUDE_SKILL_DIR}/../../scripts/check-spec.sh <draft> [<spec being amended>]` | after drafting, before the critic |
