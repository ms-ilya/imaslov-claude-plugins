---
name: feature-spec
description: >-
  Bounded requirements interview that ends in a verified written spec. Grounds
  itself in the repo, grills in capped rounds tracked against a coverage
  taxonomy, proposes and records an implementation strategy, builds a glossary
  and ADRs, then drafts and critiques a spec. Use when planning a
  feature before any code is written.
argument-hint: "[feature idea] [--fast|--deep] [--resume] [--scope <path>]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, AskUserQuestion
disable-model-invocation: true
---

# ABOUTME: Orchestrator for the bounded requirements interview that produces a critic-verified feature spec.

You run a **bounded, resumable requirements interview** and turn it into a
verified spec. Ground → grill under a coverage budget → choose a strategy →
promote decisions → draft → critique → write.

You stop at the spec. No implementation, no task breakdown, no estimates.

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

## Track your progress

**Copy this checklist into your first reply and tick items as you go.** It is the
only defence against dropping a step under load, and the round block is repeated
per round on purpose — R1 and R7 are the two rules that slip first.

```
feature-spec: <slug>  ·  mode: <fast|default|deep>
- [ ] P0 resolved: dirs, stack, principles, mode announced
- [ ] P1 grounded: agents dispatched in ONE message, facts written to tree.md
- [ ] Round n: answers + rationale written to tree.md   (R1, before anything else)
- [ ] Round n: ## Protocol counters updated             (R7)
- [ ] Round n: check-tree.sh clean
- [ ] Round n: coverage re-scored and printed
- [ ] P3 strategy: chosen AND rejected recorded, or skip announced (R16)
- [ ] P4 ADRs: three-part test run on each candidate
- [ ] P5 drafted in memory, every FR/SC source-tagged   (R10)
- [ ] P5 check-spec.sh clean
- [ ] P6 critic dispatched with the packet, not the draft
- [ ] P7 counted cost reported                          (R6, R11)
```

## Depth modes

| Mode | Rounds | Fact-finders | Strategy | Critic |
|---|---|---|---|---|
| `--fast` | 1 | 1 locate | skipped | skipped |
| default | ≤3, 4 on unlock | 1 locate + 1 interpret | if >1 approach viable | 1 agent, 3 lenses |
| `--deep` | ≤5 | 2 locate + 2 interpret | always | 3 parallel lenses |

**`--fast` renders as Channel B only** — no picker. Every question carries a
pre-accepted recommendation; the user overrides only what is wrong, in one reply.
A picker cannot be pre-accepted, which is the interaction this mode avoids.

**The 4th round unlocks only when all three hold**, checked once at the end of
round 3: ≥2 categories still Missing; the guard has not tripped; and round 3
moved at least one category. Announce the outcome either way and record it.

**Never more than 5 rounds in any mode.** At 25 questions the feature should have
been split — say so instead of asking a sixth round.

## Arguments

`$ARGUMENTS` is free text. In order:

1. Extract flags: `--fast`, `--deep`, `--resume`, `--scope <path>`.
2. If what remains matches an existing slug, treat it as one. Directories are
   date-prefixed, so **resolve by glob `*-<slug>`**: one match proceeds; several
   are listed for the user to pick; none falls through to 3. Amend reuses the
   matched directory and **never re-dates it**.
3. Otherwise treat it as the feature idea and slugify it.
4. Nothing left and no `--resume` → list existing slugs, ask for an idea, stop.
5. `--fast` and `--deep` together → error. Do not guess.
6. `--resume` means *continue an interview that never reached Phase 7*. Re-read
   `tree.md`, re-anchor from `## Protocol`, re-enter at `Next phase`. On a slug
   that did reach Phase 7 there is nothing to resume — fall through to the
   three-way choice below.

## The counter guard

You **cannot** observe your own context usage. Never report a percentage (R11).
The guard counts things you did. All six counters live in `tree.md`'s
`## Protocol` block — a tally in working memory does not survive a compaction.

| Counter | Threshold |
|---|---|
| Reference files loaded | ≥ 7 |
| Fact-finder dispatches | ≥ 3 |
| Files you read into context | ≥ 8 |
| Any single `Read` returning >500 lines | 1 |
| Rounds completed | ≥ 4 |
| Questions asked, cumulative | ≥ 22 |

**Trips when any two are at or over threshold, evaluated once, at the end of a
round.** The last two sit above anything default mode reaches: the guard scores
context pressure only, never a budget the mode already governs. The stack layer
counts as the two files it is — D6's 10 slots are a design budget, not this one.

> **On trip: stop grilling immediately.** Move every open and blocked question to
> Deferred, say plainly that you are stopping early to preserve room to draft,
> and go to Phase 5. A spec with five open markers is a deliverable. A compacted
> interview that never reached drafting is nothing.

---

# Phases

## Phase 0 — RESOLVE

Parse arguments. Detect, by **content** — `Glob` does not reliably match
`.git/`, and a project name proves nothing about its stack:

| Thing | Default | Detection wins |
|---|---|---|
| Spec dir | `docs/specs/` | existing `docs/specs/`, `specs/`, `.plans/` |
| Glossary | `<specdir>/GLOSSARY.md` | never overridden — an existing root glossary or `memory-bank/` is **read**, linked, never written |
| ADR directory | `docs/adr/` | existing `docs/adr/`, `docs/adrs/`, `adr/` |
| Stack layer | none | `.swift`, `Package.swift`, `*.xcodeproj`, `*.xcworkspace` **within the feature's scope** → swift |
| Principles | none | `AGENTS.md`, `CLAUDE.md`, `.claude/rules/*.md` |

An existing slug offers three choices, never a silent overwrite (R15):
**amend** (append a session, reopen deferred items, re-draft, strike through
superseded answers), **restart** (archive to `tree.archived-<date>.md`), or
**read-only** (print state, stop).

Announce mode, cap and unlock (R3). Say in one line that drafting runs on the
user's session model, that you cannot see your own context usage, and that
`/context` shows it. Nothing is written yet — say so when you first create the
directory.

Load `${CLAUDE_SKILL_DIR}/references/tree-format.md`.

## Phase 1 — GROUND

**On swift detection, load the two `references/swift/` files before dispatching**
— they name what to look for, so loading them afterwards shapes nothing.

Dispatch fact-finders — **all in one message** so they run concurrently.
Sequential dispatch multiplies the only part of the run the user waits on.

Say what is happening before dispatching, and nothing while they run. Each agent
gets **specific** questions and the scope hint — never "sweep the repo", which
makes an agent read the world.

**Route each question by tier** (the `Agent` tool's `model` parameter overrides
the agent's frontmatter per dispatch):

- **Locate** — a path, a name, a yes/no on existence, a count. Anything a search
  could confirm. → `model: haiku`.
- **Interpret** — a pattern, a convention, a shape, a judgement about how code is
  organised. → leave the frontmatter default (`sonnet`).

When genuinely unsure, use interpret. The cost difference on one question is
trivial; a wrong grounding fact poisons every question built on it.

Read the glossary, the decision-record directory and the principles files
**yourself**, not through an agent — they are small and needed verbatim.

Write `## Problem`, `## Reads`, `## Grounding facts` and `## Principles in force`
to `tree.md`. Show a short "what I found", including **what it made unnecessary
to ask** — a fact found is a question never asked.

## Phase 2 — GRILL *(loop)*

First round only: load `${CLAUDE_SKILL_DIR}/references/coverage-taxonomy.md`,
`${CLAUDE_SKILL_DIR}/references/question-format.md`, and `${CLAUDE_SKILL_DIR}/references/frontier.md` (default and deep).

1. Score coverage against the taxonomy, using its category names verbatim.
2. Build the frontier. Rank by Impact × Uncertainty. **Take the top 5, never
   more** (R9). Fewer is fine — padding a round is how it starts feeling like a
   form.
3. Facts are found **before** the round (R2). It is not mechanically possible to
   hold a user prompt open while agents run.
4. Render the round: **one `AskUserQuestion` call plus one markdown block**,
   never two pickers. Closed 2–4 way choices go in the picker (≤4, `header` ≤12
   chars, "why it matters" inside `question`, recommended option first tagged
   `(Recommended)`). Everything else goes in the markdown block with the coverage
   table and the `skip` / `stop` offer.
5. **Append every answer and its rationale to `tree.md` via `Edit`, not `Write`**
   (R1). Rewriting a 300-line file each round costs several times what patching
   it does.
6. Challenge fuzzy terms — at most two per round — and write glossary entries as
   they resolve, not batched at the end. Load `${CLAUDE_SKILL_DIR}/references/glossary-format.md` on
   the first one.
7. Re-score coverage, print the table with a line explaining anything that did
   not move, and offer continue / defer the rest / stop.
8. Update the `## Protocol` counters (R7), then evaluate the guard.
9. **Validate before the next round**, and fix until clean:
   `bash ${CLAUDE_SKILL_DIR}/../../scripts/check-tree.sh <specdir>/tree.md`
   It checks what you would otherwise self-police — verbatim category names,
   `Clear*` with its count, `N/A` with a reason, rationale and round on every
   answer, unique ids, transitive deferral. Interpretation drifts; this does not.

**Deferral is transitive:** deferring a question defers everything blocked behind
it, in one step. Never leave an orphan in `## Blocked` pointing at a deferred
parent.

**A category is `Clear*` only if nothing High-impact in it was deferred.** A
High-impact deferral holds the category at `Partial`. Print `Clear*` with its
count, everywhere, always.

Loop while round < cap and Missing categories remain. At the cap in default mode,
evaluate the 4th-round unlock once.

## Phase 3 — STRATEGY

Skipped in `--fast`. Skipped in default when exactly one approach is viable —
**and say so out loud** (R16).

Propose 2–3 approaches with trade-offs. Use `AskUserQuestion` with `preview`
blocks: ≤12 lines, **shape not code**. This is the one place in the run where the
user compares shapes rather than answering a question.

Record chosen **and** rejected, with reasons.

If the choice is genuinely contested and hard to reverse, point at
`/multi-agent-debate` rather than rebuilding it here. A suggestion, never a call.

## Phase 4 — PROMOTE DECISIONS

Load `${CLAUDE_SKILL_DIR}/references/adr-format.md` only if a candidate exists.

**Three tests, all three or skip** (R14): hard to reverse? surprising without
context? the result of a real trade-off? A typical interview promotes zero or
one. Three means the test is being applied loosely.

Write qualifying ADRs as `Status: Proposed` with a back-link to the spec
directory, named to match the directory's own convention. Add them to `## Reads`.

## Phase 5 — DRAFT

Load `${CLAUDE_SKILL_DIR}/references/spec-template.md` — an instruction file, not content.

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

Skipped in `--fast`.

Dispatch `spec-critic` with the **critic packet inline**: the requirement and
criterion list with source tags, the acceptance scenarios, the coverage table
with `Clear*` marks intact, the deferred list, the chosen and rejected
strategies, promoted ADR titles with their one-line decisions, the principle
lines verbatim, and `${CLAUDE_SKILL_DIR}/references/critic-rubric.md` **inline** — the agent cannot
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

**Counted cost, never estimated** (R6, R11): rounds used of cap · questions
asked · fact-finder dispatches · reference files loaded · critic passes.

When more than a third of categories ended `Clear*`, say so plainly: *"most of
this spec is open questions — consider another round, or a narrower feature."*

---

## Degradation

Load `${CLAUDE_SKILL_DIR}/references/degradation.md` the moment you hit a failure
path, or are about to invent a failure behaviour. Every row degrades toward
**producing something**, and nothing is papered over silently.

## Reference loading

Load at the phase that needs it, **once**. Track what is loaded; never re-read.
`--fast` loads 4, default at most 7 — and 2 more on a Swift repo, in both.

| File | Loaded at | Modes |
|---|---|---|
| `${CLAUDE_SKILL_DIR}/references/tree-format.md` | Phase 0 | all |
| `${CLAUDE_SKILL_DIR}/references/coverage-taxonomy.md` | Phase 2, first round | all |
| `${CLAUDE_SKILL_DIR}/references/frontier.md` | Phase 2, first round | default, deep |
| `${CLAUDE_SKILL_DIR}/references/question-format.md` | Phase 2, first round | all |
| `${CLAUDE_SKILL_DIR}/references/glossary-format.md` | Phase 2, first fuzzy term | default, deep |
| `${CLAUDE_SKILL_DIR}/references/adr-format.md` | Phase 4, only if a candidate exists | default, deep |
| `${CLAUDE_SKILL_DIR}/references/spec-template.md` | Phase 5 | all |
| `${CLAUDE_SKILL_DIR}/references/critic-rubric.md` | Phase 6 — **passed inline to the agent**, not loaded by you | default, deep |
| `${CLAUDE_SKILL_DIR}/references/swift/fact-finding.md` | Phase 1, on swift detection | all |
| `${CLAUDE_SKILL_DIR}/references/swift/seams.md` | Phase 1, on swift detection | all |
| `${CLAUDE_SKILL_DIR}/references/degradation.md` | on hitting a failure path | all |

## Scripts

Run these; do not reimplement their checks in prose.

| Script | When |
|---|---|
| `${CLAUDE_SKILL_DIR}/../../scripts/check-tree.sh <tree.md>` | end of every round, after the counters |
| `${CLAUDE_SKILL_DIR}/../../scripts/check-spec.sh <draft> [<spec being amended>]` | after drafting, before the critic |
