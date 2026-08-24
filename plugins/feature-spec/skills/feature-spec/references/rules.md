# The rules — canonical text

**This file is the single source of truth for R1–R17.** All three `SKILL.md`
files reproduce the whole table verbatim, each followed by a line naming the
rules that stage cannot act on. That is deliberate: one stable numbering means
`R7` denotes the same rule in a grill transcript, a write transcript and a
critique, and a rule that arrives by reference is a rule that may not have
arrived at all.

**Reproduction is deliberate; drift is not.** `scripts/test-checks.sh` asserts
that every `| **Rn** |` line in every `SKILL.md` is byte-identical to its line
below, so the copies cannot diverge without a test failing.

**Edit this file first, then propagate to all four skills, then run the test.**

## Which rules each stage can act on

The full table ships everywhere; this is what the applicability note under each
copy must say.

| Skill | Phases | Can act on | Reproduced but inert |
|---|---|---|---|
| `feature-spec` | 0–7 | R1–R17 | R18–R21 — the implementation plan |
| `feature-spec-grill` | 0–4 | R1–R9, R11–R17 | R10, R12 — drafting and the critic; R18–R21 — the plan |
| `feature-spec-write` | 5–7 | R10–R17 | R1–R9 — the interview; R18–R21 — the plan |
| `feature-spec-plan` | 8–11 | R11–R13, R17–R21 | R1–R10, R14–R16 — the interview and the spec |

## The table

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

## What each rule is defending against

Not restatements — the reason the rule is worth its line.

| Rule | The failure it prevents |
|---|---|
| R1, R7 | A compaction lands mid-interview and the answers, or the process state, are gone. These are the two rules that slip first, which is why both are checked mechanically. |
| R2 | An agent dispatched mid-round, which is not mechanically possible while a prompt is open. |
| R3, R16 | A run whose shape the user cannot predict, and a phase quietly dropped under load. |
| R4, R8 | A question that reads as a form: no recommendation, or one the repo already answered. |
| R5, R9 | An interview that expands until there is no room left to draft. |
| R6, R11 | A fabricated cost figure. The plugin cannot observe its own context, and a number it cannot count is invention. |
| R10 | A spec that asserts what the interview never decided — the failure this plugin exists to prevent. |
| R12 | A critic that becomes a gate, so the deliverable never ships. |
| R13 | A critic enforcing its own taste under the name of the project's rules. |
| R14 | ADR inflation, which makes the decision record worthless by making it long. |
| R15, R17 | Silent damage to files the user did not offer up. |
| R18 | A plan that reads complete while silently dropping a requirement — the one failure that makes a checked plan worse than none. |
| R19 | Work that entered the plan because it seemed sensible rather than because anything asked for it. |
| R20 | A plan built on an answer the interview deliberately did not give, which is how a deferral turns into an assumption nobody noticed making. |
| R21 | Implementation decisions laundered through a document that looks verified. The spec is behaviour-only by design, so every technology choice in the plan is new — and new decisions must read as decisions. |
