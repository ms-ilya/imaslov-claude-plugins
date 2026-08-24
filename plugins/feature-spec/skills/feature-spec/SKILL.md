---
name: feature-spec
description: "Bounded requirements interview that ends in a critic-verified feature spec. Use when planning a feature before any code is written, or to amend an existing spec."
argument-hint: "[feature idea | --prior-art <doc>] [--fast|--deep] [--resume] [--scope <path>]"
disable-model-invocation: true
effort: high
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-protocol.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-tree.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-spec.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-critique.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/make-packet.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/make-traceability.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/spec-diff.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/undo-round.sh *)
hooks:
  PostToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/hook-validate.sh"
---

# ABOUTME: Orchestrator for the bounded requirements interview that produces a critic-verified feature spec.

You run a **bounded, resumable requirements interview** and turn it into a
verified spec. Ground → grill under a coverage budget → choose a strategy →
promote decisions → draft → critique → write.

You stop at the spec. No implementation, no task breakdown, no estimates.

## Critical rules

Canonical text: `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/rules.md`. Edit there, propagate to all four skills, then run `scripts/test-checks.sh`.

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
| **R18** | **MUST** cover every requirement and success criterion in the spec with at least one task, or record it under `## Not planned` with the reason it was left out. |
| **R19** | **MUST** tag every task with the requirements it covers. Work no requirement asked for is legal, and is recorded under `## Enabling work` with what it unblocks — never left untagged. |
| **R20** | **NEVER** plan around an unresolved `[NEEDS CLARIFICATION]` as though it were settled. Carry every marker into the plan, and mark the tasks it blocks. |
| **R21** | **NEVER** present an implementation decision the spec did not settle as settled. It goes in `## Plan assumptions` with what reversing it would cost. |

**R18–R21 govern the implementation plan, which this pipeline does not
produce.** They are reproduced verbatim so the four skills share one rule
block; the rules you can act on here are R1–R17.

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

## The counter guard

You **cannot** observe your own context usage. Never report a percentage (R11).
The guard counts things you did. Every counter lives in `tree.md`'s
`## Protocol` block — a tally in working memory does not survive a compaction.

| Counter | Threshold | Why that number |
|---|---|---|
| Lines read into context | ≥ 1200 | volume, not calls — a 40-line slice and a 900-line file are not the same read |
| Fact-finder dispatches | mode's allowance **+ 2** | `--fast` 1 · default 2 · `--deep` 4 |
| Reference files loaded | mode's budget **+ 2** | `--fast` 7 · default and `--deep` 10 |
| Rounds completed | ≥ 4 | |
| Questions asked, cumulative | ≥ 22 | |

**Trips when any two are at or over threshold, evaluated once, at the end of a
round.** `bump-protocol.sh` computes all of this; never evaluate it by hand.

Two thresholds are **relative to the mode**, and that is the point. `--deep`
mandates four fact-finders and loads ten reference files, so fixed thresholds of
3 and 7 put two counters at threshold before the interview asked anything — the
guard scored the mode's own configuration and handed `--deep` a single round on
any repo with a stack layer. A guard that trips on the expected case is not a
guard.

**Lines, not calls.** Context pressure is volume. Record each `Read` with
`--read <lines>`, which bumps the read count, the line total and the maximum
together, so the three cannot disagree.

> **On trip: stop grilling immediately.** Move every open and blocked question to
> Deferred, say plainly that you are stopping early to preserve room to draft,
> and go to Phase 5. A spec with five open markers is a deliverable. A compacted
> interview that never reached drafting is nothing.

## Scripts

Run these; do not reimplement their checks in prose.

| Script | When |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/scripts/bump-protocol.sh <tree.md> --round …` | end of every round — owns the counters and the guard (exit 3 = just tripped) |
| `${CLAUDE_PLUGIN_ROOT}/scripts/check-tree.sh <tree.md>` | end of every round, after the counters |
| `${CLAUDE_PLUGIN_ROOT}/scripts/check-tree.sh <tree.md> --doctor` | only when the record will not parse — names the broken section and prints its repair |
| `${CLAUDE_PLUGIN_ROOT}/scripts/check-spec.sh <draft> --tree <tree.md> [--prev <spec being amended>]` | after drafting, before the critic |
| `${CLAUDE_PLUGIN_ROOT}/scripts/check-critique.sh <p1> [--single \| <p2>]` | after each critic pass, and to reconcile the two |
| `${CLAUDE_PLUGIN_ROOT}/scripts/make-packet.sh <spec> --tree <tree.md> [--lens <name>]` | Phase 6 — builds the critic packet; never assemble it by hand |
| `${CLAUDE_PLUGIN_ROOT}/scripts/make-traceability.sh <spec> --tree <tree.md>` | Phase 7 |
| `${CLAUDE_PLUGIN_ROOT}/scripts/undo-round.sh <tree.md>` | only when the user asks to take back the last round — strikes its answers through, returns their questions to the frontier and rewinds the counters |
| `${CLAUDE_PLUGIN_ROOT}/scripts/spec-diff.sh <new> <prev>` | on an amendment, after writing — renders what actually changed; `critique.md` structurally cannot show this, because the critic never sees the previous version |

**The hook validates every write, closed-world:** it checks what you wrote, never
what you have not written yet. A Phase 1 record with no coverage table and a draft
with no scenarios both pass. A fabricated citation fails at any stage. Run the
script yourself at the gate — that is where completeness is required.

## Reference loading

Load at the phase that needs it, **once**. Track what is loaded; never re-read.
**Budget: `--fast` 5, default and `--deep` 8 — plus the stack layer's 2 on a
Swift, TypeScript or Python repo, so 7 and 10.** The guard's threshold is
derived from these numbers, so correcting one corrects the other.

| File | Loaded at | Modes |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/rules.md` | never — the rules are inlined above; this is the canonical copy to edit | — |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/tree-format.md` | Phase 0 | all |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/coverage-taxonomy.md` | Phase 2, first round | all |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/frontier.md` | Phase 2, first round | default, deep |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/question-format.md` | Phase 2, first round | all |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/glossary-format.md` | Phase 2, first fuzzy term | default, deep |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/adr-format.md` | Phase 4, only if a candidate exists | default, deep |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/drafting.md` | Phase 5 — carries phases 5, 6 and 7 | all |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/spec-template.md` | Phase 5 | all |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/critic-rubric.md` | Phase 6 — **passed inline to the agent**, not loaded by you | default, deep |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/<stack>/fact-finding.md` | Phase 1, on stack detection — `swift`, `typescript` or `python` | all |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/<stack>/seams.md` | Phase 1, on stack detection | all |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/degradation.md` | on hitting a failure path | all |

## Modes and arguments

Load `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/invocation.md` in Phase 0
for the depth-mode table, the argument grammar, the 4th-round unlock rule and the
**prior-art input mode**. **Once.** Both are written into `## Protocol` as soon as
they resolve, so every later round reads the record, not the file.

**When the input is an existing document rather than an idea** — a findings
write-up, a migration plan, a design note — that is `--prior-art`, and it changes
Phase 1's job from *summarise it* to *falsify it*. Do not skip the load: the
grammar assumes an unformed idea, and a document handed to the ordinary path gets
believed rather than checked.

Three things are load-bearing enough to state here rather than behind a load:
**never more than 5 rounds in any mode**, **never more than 5 questions in one
round** (R9), and **`--fast` and `--deep` together is an error** — do not guess
which was meant.

## Phase 0 — RESOLVE

Parse arguments, then **detect by looking**. The table below says *what* to
establish, not how to find it — searching is yours to do, and how deep to look is
a judgement about this repo that no fixed command makes correctly. A monorepo
buries its services five directories down; a library has everything at the root.

`Glob` does not reliably match `.git/`, and a project name proves nothing about
its stack — so detect by **content**, and scope the search to the feature:

| Thing | Default | Detection wins |
|---|---|---|
| Spec dir | `docs/specs/` | existing `docs/specs/`, `specs/`, `.plans/` |
| Glossary | `<specdir>/GLOSSARY.md` | never overridden — an existing root glossary or `memory-bank/` is **read**, linked, never written |
| ADR directory | `docs/adr/` | existing `docs/adr/`, `docs/adrs/`, `adr/` |
| Stack layer | none | **within the feature's scope**, by content: `.swift`, `Package.swift`, `*.xcodeproj`, `*.xcworkspace` → `swift` · `tsconfig.json`, `.ts`, `.tsx` → `typescript` · `pyproject.toml`, `requirements.txt`, `.py` → `python` |
| Principles | none | `AGENTS.md`, `CLAUDE.md`, `.claude/rules/*.md` — **an absolute or `~`-prefixed path is legal**: a machine may keep its only copy outside the repo. Record it in `## Reads` as written; it is expanded and checked, not skipped. |
| VCS state | — | one line in the report: branch, and **whether the repo has any commits at all**. `spec-diff.sh` and the `--prev` amendment flow both assume history exists, and "there is no history" is often itself a finding the spec is about. |

An existing slug offers three choices, never a silent overwrite (R15):
**amend** (append a session, reopen deferred items, re-draft, strike through
superseded answers), **restart** (archive to `tree.archived-<date>.md`), or
**read-only** (print state, stop).

Announce mode, cap and unlock (R3). Say in one line that drafting runs on the
user's session model, that you cannot see your own context usage, and that
`/context` shows it. Nothing is written yet — say so when you first create the
directory.

Load `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/tree-format.md`.

## Phase 1 — GROUND

**On a stack detection, load that stack's two `references/<stack>/` files before
dispatching** — they name what to look for, so loading them afterwards shapes
nothing. Layers ship for `swift`, `typescript` and `python`.

**Exactly one layer loads, or none.** On a repo that is both — a Python service
with a TypeScript front end — the layer is the one the *feature's scope* is in,
not the one the repo has more of. When the scope spans both, ask which side the
feature lives on before dispatching: it is one question, and it saves a round of
questions aimed at the wrong stack.

Dispatch fact-finders — **all in one message** so they run concurrently.
Sequential dispatch multiplies the only part of the run the user waits on.

Say what is happening before dispatching, and nothing while they run. Each agent
gets **specific** questions and the scope hint — never "sweep the repo", which
makes an agent read the world.

**Shape-check every return before you use it.** A fact-finder can end its turn on
a dangling narration — *"Now let me verify Package.resolved"* — and hand back no
report at all. A reply that does not contain `Q:` / `FACT:` / `EVIDENCE:` /
`CONFIDENCE:` / `NOT_FOUND:` is not an answer: `SendMessage` the agent once with
*"return the report in the schema; nothing else"*, and only then treat the
dispatch as failed. One resume costs a round trip; a silently missing fact costs
a wrong question built on top of it.

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

First round only: load `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/coverage-taxonomy.md`,
`${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/question-format.md`, and `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/frontier.md` (default and deep).

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
   they resolve, not batched at the end. Load `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/glossary-format.md` on
   the first one.
7. Re-score coverage, print the table with a line explaining anything that did
   not move, and offer continue / defer the rest / stop.
8. Update the `## Protocol` counters and evaluate the guard **with the script,
   not by hand** (R7):
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-protocol.sh <specdir>/tree.md --round --questions <n> --fact-finders <n> --references <n> --read <lines> [--read <lines> …]`
   One `--read` per `Read` you made, carrying its line count.
   It rewrites the block in canonical form, corrects a questions count that has
   fallen behind the ids on the page, and **recomputes the guard from the
   counters** rather than taking your word for it. **Exit 3 means the guard just
   tripped** — stop grilling immediately (R5) and go to Phase 5. Six numbers
   re-transcribed by hand at the end of every round is the shape of an error.
9. **Validate before the next round**, and fix until clean:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-tree.sh <specdir>/tree.md`
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

Load `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/adr-format.md` only if a candidate exists.

**Three tests, all three or skip** (R14): hard to reverse? surprising without
context? the result of a real trade-off? A typical interview promotes zero or
one. Three means the test is being applied loosely.

Write qualifying ADRs as `Status: Proposed` with a back-link to the spec
directory, named to match the directory's own convention. Add them to `## Reads`.

## Phase 5 — DRAFT

Load `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/drafting.md` and follow
it. It carries phases 5, 6 and 7 — drafting under the source-tag rule, the critic
packet and its two passes, and the report.

**Read `tree.md` and exactly the files in its `## Reads` list. Nothing else.** No
re-interview, no `## History`. Every requirement, criterion and scenario carries a
source tag naming the `tree.md` line it came from; anything untraceable is **cut
or marked, never asserted** (R10).

---

## Degradation

Load `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/degradation.md` the moment you hit a failure
path, or are about to invent a failure behaviour. Every row degrades toward
**producing something**, and nothing is papered over silently.

