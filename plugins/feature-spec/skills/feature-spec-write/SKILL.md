---
name: feature-spec-write
description: "Drafts, critiques and writes a feature spec from an existing design record. Use when an interview has finished and its spec has not been written yet."
argument-hint: "<slug> | --from-tree <path> [--out <dir>]"
disable-model-invocation: true
effort: high
context: fork
agent: general-purpose
background: false
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-spec.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-tree.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-critique.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/make-packet.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/make-traceability.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/spec-diff.sh *)
hooks:
  PostToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/hook-validate.sh"
---

# ABOUTME: Runs phases 5-7 of the feature-spec pipeline — draft, critique, write — from a design record alone.

You turn an existing design record into a written, critic-verified spec.

Self-contained: everything you need is below or in
`${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/`. Do not read another skill's `SKILL.md`.

**This command exists to be run in a fresh session**, with no memory of the
interview. That is not a limitation to work around — it is the property that
makes the design record worth writing.

## Critical rules

Canonical text: `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/rules.md`. Edit there, propagate here, then run `scripts/test-checks.sh`.

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

**R1–R9 govern the interview and R18–R21 the implementation plan, neither of
which this stage runs.** They are reproduced verbatim so the four skills share
one rule block; the rules you can act on here are R10–R17.

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

## This runs in isolation

`context: fork` — the skill body is the whole prompt, and there is no conversation
history behind it. That is the point: the design record is the only input, so a
half-remembered interview cannot leak in and be mistaken for something the record
says. It also means drafting runs at this skill's own model rather than whatever
the session happened to be set to.

Two consequences to hold on to:

- **You cannot ask the user anything.** Every path that would otherwise ask must
  instead do the safe thing and report it. No argument → list and stop. An
  ambiguous slug → list the matches and stop. An existing `spec.md` → stop and
  say it is an amendment, which is `/feature-spec`'s three-way choice (R15).
- **Nothing is inherited.** Read `tree.md` and exactly the files its `## Reads`
  names. If something you need is not in the record, that is a finding about the
  record — `[NEEDS CLARIFICATION]` — not a gap to fill from memory (R10).

## Resolving the slug

`$ARGUMENTS` is a slug. Directories are date-prefixed, so **resolve by glob
`*-<slug>`**: one match proceeds; several are listed for the user to pick; none
means stop and list what exists.

No argument → **list the slugs that have a design record but no spec, and stop.**
List and stop, not list and ask: this skill runs in a forked context with no
conversation to ask into, so a question here would go nowhere. The user re-invokes
with the slug they want.

**Stop and say so** if the record is missing or unparseable, or if `spec.md`
already exists. A spec already written is an **amendment**, which is
`/feature-spec`'s three-way choice — amend, restart or read-only — and not
something this command decides on its own (R15).

`--from-tree <path>` takes a design record from anywhere instead of resolving a
slug: the record is the only input this command has, so it does not have to be
one this project's interview produced. The output directory is the record's own,
unless `--out <dir>` says otherwise. One person can interview and another draft,
with the reasoning surviving the handoff intact.

When the record does not parse, run
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-tree.sh <tree.md> --doctor`. It names
every broken section and prints its repair from the shipped skeleton, which is a
route back rather than a dead end. Load
`${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/tree-format.md` only if the
doctor's output is not enough.

---

# Phases

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
path. The rows that apply here: an unparseable record, a critic still blocking
after two passes, and an existing spec directory written by another tool.

## Reference loading

| File | Loaded at |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/drafting.md` | Phase 5 — carries phases 5, 6 and 7 |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/spec-template.md` | Phase 5 |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/critic-rubric.md` | Phase 6 — **passed inline to the agent**, not loaded by you |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/tree-format.md` | only to diagnose an unparseable record |
| `${CLAUDE_PLUGIN_ROOT}/skills/feature-spec/references/degradation.md` | on hitting a failure path |

## Scripts

Run this; do not reimplement its checks in prose.

| Script | When |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/scripts/check-tree.sh <tree.md> --doctor` | only when the record will not parse — names the broken section and prints its repair |
| `${CLAUDE_PLUGIN_ROOT}/scripts/check-spec.sh <draft> --tree <tree.md> [--prev <spec being amended>]` | after drafting, before the critic |
| `${CLAUDE_PLUGIN_ROOT}/scripts/check-critique.sh <p1> [--single \| <p2>]` | after each critic pass, and to reconcile the two |
| `${CLAUDE_PLUGIN_ROOT}/scripts/make-packet.sh <spec> --tree <tree.md> [--lens <name>]` | Phase 6 — builds the critic packet; never assemble it by hand |
| `${CLAUDE_PLUGIN_ROOT}/scripts/make-traceability.sh <spec> --tree <tree.md>` | Phase 7 |
| `${CLAUDE_PLUGIN_ROOT}/scripts/spec-diff.sh <new> <prev>` | on an amendment, after writing — renders what actually changed; `critique.md` structurally cannot show this, because the critic never sees the previous version |

**The hook validates every write, closed-world:** it checks what you wrote, never
what you have not written yet. A Phase 1 record with no coverage table and a draft
with no scenarios both pass. A fabricated citation fails at any stage. Run the
script yourself at the gate — that is where completeness is required.