# The rules — canonical text

**This file is the single source of truth for the rules.** Each `SKILL.md`
reproduces, verbatim, the rows its stage can act on. One stable numbering means
`R10` denotes the same rule in a run transcript, a critique and a plan, and a rule
that arrives by reference is a rule that may not have arrived at all.

The maintainer self-test, which is not shipped with the plugin, asserts that
every `| **Rn** |` row in a `SKILL.md` is byte-identical to its row below, and
that every row below is carried by at least one skill. **Edit this file first,
then the skills, then run the test.**

Numbers are identifiers, not a count. A retired number is never reused, so the
gaps are deliberate: R3, R5 and R7 are retired.

## Which rules each skill carries

| Skill | Phases | Carries |
|---|---|---|
| `feature-spec` | 0–7 | R1, R2, R4, R6, R8–R17 |
| `feature-spec-plan` | 8–11 | R11–R13, R17–R21 |

## The table

Each row states the rule and the failure it prevents.

| ID | Rule |
|---|---|
| **R1** | Write every decision and its rationale to `tree.md` before rendering the next round and before any other tool call: at intake for what the input already decided, then once per round. Whatever exists only in the conversation is gone after a compaction. |
| **R2** | Find facts before a round, never during one. A prompt that is open to the user cannot be held while an agent runs. |
| **R4** | Give every question a recommended answer and one line naming what the answer changes. Without them a round reads as a form. |
| **R6** | Report counted cost when the run ends: clarifying rounds and critic passes. Both can be counted from the files the run wrote. |
| **R8** | Do not ask the user what a fact-finder could look up, or what their own input already answers. One such question costs the trust every other question depends on. |
| **R9** | Ask at most 5 questions in a round and run at most 2 rounds in a session. What is still open after that ships as `[NEEDS CLARIFICATION]`: an interview that keeps growing means the input needs work, not that the run needs more rounds. |
| **R10** | Every requirement, success criterion, out-of-scope line and implementation constraint in the spec carries a source tag that resolves in `tree.md`. Cut anything that does not, or mark it `[NEEDS CLARIFICATION]`: a spec asserting what was never decided is the failure this plugin exists to prevent. |
| **R11** | State no number you cannot count. Token spend, context percentage and elapsed cost cannot be observed from inside a run, so reporting one is invention. |
| **R12** | The critic never blocks the deliverable. Two passes at most, then write, with the unresolved findings attached to the critique file. |
| **R13** | Enforce the rules the project stated, never your own taste. A rule nobody wrote down is not a finding. |
| **R14** | Write an ADR only for a decision that passes all three tests: hard to reverse, surprising without context, the result of a real trade-off. A long decision record is a worthless one. |
| **R15** | Never silently overwrite an existing spec. Offer amend, restart or read-only, and wait for the choice. |
| **R16** | Never silently skip a phase. When the clarifying phase or the strategy phase does not run, say so and say why. |
| **R17** | Write only inside the spec root (`docs/specs/` unless the project keeps one elsewhere), plus the ADR directory. Every other file in the repository is read-only to you. |
| **R18** | Cover every requirement and success criterion in the spec with at least one task, or list it under `## Not planned` with the reason it was left out. A plan that silently drops a requirement reads exactly like one that covers it. |
| **R19** | Tag every task with the requirements it covers. Work no requirement asked for is legal, and goes under `## Enabling work` with what it unblocks; it is never left untagged. |
| **R20** | Do not plan around an unresolved `[NEEDS CLARIFICATION]` as though it were settled. Carry every marker into the plan and mark the tasks it blocks, or a deferral becomes an assumption nobody noticed making. |
| **R21** | Do not present an implementation decision the spec did not settle as settled. It goes in `## Plan assumptions` with what reversing it would cost: the spec is behaviour-only, so every technology choice in the plan is new. |
