# `tree.md` — the design record

`tree.md` is the **sole authoritative input to drafting.** Not a bookmark, not a
log — the record. Everything the spec says must be traceable to a line in it.

Written to immediately, every round, before anything else (R1). A tally held in
working memory does not survive compaction; the file does.

## Contents
- The skeleton
- What each section is for
- Eleven rules the format depends on
- When the file will not parse

## The skeleton

```skeleton
# Design tree: <feature name>

## Problem
One line, in the user's own words, corrected in round 1: batch imports restart
from zero after a crash, and a large import can take longer than the window
between crashes.

## Protocol
Slug: 2026-08-21-retry-uploads   Started: 2026-08-21   Mode: default
Stack: none   Scope: cmd/ingest
Round: 2 of 3   4th round unlocked: no   Next phase: 2
Counters: questions 10 · fact-finders 2 · references 4 · orchestrator reads 5 · lines read 340 · critic passes 0
Largest single read: 180 lines
Guard: not tripped
Rules in force: R1 R2 R5 R8 R9

## Reads
Files the drafting phase may open, and nothing else:
- docs/specs/GLOSSARY.md
- docs/adr/0004-checkpoint-file-over-database.md
- AGENTS.md   (principles)

## Coverage
| Category | Status |
|---|---|
| Problem & outcome | Clear |
| Scope boundary | Clear |
| Behaviour & flows | Partial |
| Domain & data | Clear |
| Interface & platform surface | N/A — no user-facing surface |
| Failure & edge cases | Missing |
| Constraints & quality bar | Clear* (2 deferred) |
| Integration & dependencies | Clear |
| Verification | Missing |
| Vocabulary | Clear |

## Principles in force
- From AGENTS.md: "smallest reasonable change"; "no backward-compat shims"

## Grounding facts
1. Ingest state is a JSON checkpoint at `cmd/ingest/state.go:31` (fact-finder, r0, high)
2. Nearest analogous feature: `--replay`, same checkpoint shape (fact-finder, r0, medium)

## Settled
- **Q1 Where retry state lives** → in the existing checkpoint file. [P1]
  *Why:* one source of truth, and replay already reads it. (r1)
- **Q2 Attempt ceiling** → at most 5 attempts spread over 24h. [P2]
  *Why:* survives a workday outage, bounds file growth. (r1)

## Frontier (askable now)
- **Q7 What a partial batch does on resume** — deps: Q1 ✔ — impact H, uncertainty H

## Blocked
- **Q9 Operator-visible failure surface** — deps: Q7

## Deferred → ships as [NEEDS CLARIFICATION]
- **Q12 Per-source overrides** — low impact, decided post-launch (r2)

## Strategy
- Chosen: B — sweep the checkpoint on a timer, one in-flight batch.
- Rejected: A (retry inline, blocks ingest); C (external queue, new dependency).

## Glossary written
- Batch, Checkpoint, Attempt

## Promoted to ADR
- ADR-0004 Checkpoint file over a database for retry state — Proposed

## Sessions
- 2026-08-21 r1–r2 (initial)

## History
Superseded ## Settled entries land here. Drafting does not read this section.
```

## What each section is for

| Section | Job | Written |
|---|---|---|
| `## Protocol` | Re-anchors the **process** after a compaction, exactly as the rest re-anchors the **answers**. Without it, the round after a compaction renders the wrong format at the wrong cap. | end of every round, first (R7) |
| `## Problem` | One line: whose problem, and what changes. Written in Phase 0 from the user's own idea, corrected in round 1. Without it, drafting invents the problem statement — the single worst thing for it to invent. | Phase 0 |
| `## Reads` | The tree declares its own dependencies. Drafting opens `tree.md` plus exactly these files and nothing else. | Phase 1, appended as ADRs are promoted |
| `## Coverage` | Whether the interview keeps going. Category names are the taxonomy's **verbatim** — paraphrase them and the table stops being comparable to itself. | re-scored every round |
| `## Principles in force` | The repo's own rules, quoted. The critic enforces these, never its own taste. | Phase 1 |
| `## Grounding facts` | Numbered, each with source, round and confidence. Numbers are the source-tag target. | Phase 1 |
| `## Settled` | Answer **and rationale**, plus a `[P1]`/`[P2]`/`[P3]` tag where the answer describes user-visible behaviour. The rationale is the part a compaction destroys and the part the spec cannot be written without. | every round |
| `## Frontier` / `## Blocked` | What is askable now versus what is dependency-blocked. Two lists, not one. | every round |
| `## Deferred` | Bounded, with a reason and the round. Each becomes a `[NEEDS CLARIFICATION]` marker. | every round |
| `## Strategy` | Chosen **and rejected**, with reasons. The rejected list is what stops the same argument recurring in three months. | Phase 3 |
| `## Glossary written` / `## Promoted to ADR` | Pointers into files that live elsewhere. Titles only — the content is in the file. | Phases 2 and 4 |
| `## Sessions` | One line per session. Amendment appends; it never rewrites. | every session |
| `## History` | Overflow only. Not read when drafting. | on the 400-line rule |

## Eleven rules the format depends on

1. **Question identifiers never repeat and never renumber.** `Q7` means one
   question for the life of the file, wherever it has moved to.
2. **Every `## Settled` entry carries its round.** `(r1)` is what makes an
   answer's age legible after an amendment.
3. **`Clear*` is not `Clear`.** A category cleared by deferral prints as
   `Clear* (n deferred)`, everywhere, always. A high-impact deferral does not
   clear a category at all — it holds it at `Partial`.
4. **Deferral is transitive.** Deferring a question defers everything blocked
   behind it. Move the subtree in one step; never leave an orphan in `## Blocked`
   pointing at a deferred parent.
5. **Superseded answers are struck through, never deleted.** On amendment the
   old line stays as `~~…~~` with the new one beneath it.
6. **Past 400 lines, superseded `## Settled` entries move to `## History`.**
   The record stays complete for a human; the drafting input stays bounded.
   Nothing is ever deleted.
7. **Priority is interviewed, never inferred at drafting time.** An answer about
   user-visible behaviour carries `[P1]`, `[P2]` or `[P3]`, where **P1 alone is
   a shippable slice.** Drafting assigns no priority the tree does not hold — a
   priority invented at drafting time is a decision the user never made.
8. **A number that a success criterion will be built on lives in the answer, not
   the rationale.** *"at most 5 attempts spread over 24h"* is an answer; *"a
   sensible ceiling"* with the number buried in the `*Why:*` is not. The
   unquantified-adjective scan exists to force the number in at the moment the
   answer is given, when the user is there to supply it.
9. **`## Problem` is one line and it is never blank.** If the idea is too vague
   to state in one line, that is the first thing round 1 asks.
10. **`## Reads` may name a file outside the repository.** Write it as it is —
    `- ~/.claude/rules/swift.md   (principles, outside the repo)`. An absolute or
    `~`-prefixed path is legal and is expanded before it is checked — a machine
    may keep its only `AGENTS.md` in `~/.claude/`, and calling that real file
    invented forces the writer to quote it into the record by hand. It is
    checked, not skipped: a typo in an absolute path fails at drafting time like
    any other.
11. **`## Strategy` takes one `Chosen:` line per axis, and tolerates
    decoration.** A round can settle two independent strategy questions —
    structure and rendering, say — and each gets its own line:
    `- **Chosen (structure): C — extract HeadFrame.**` The axis in parentheses is
    optional, bold and bullets are ignored, and every requirement citing either
    one tags `← Strategy (chosen)` regardless. `Rejected:` works the same way.

## When the file will not parse

Report which section failed and stop. Offer a restart. Never guess at a
corrupted design record — a half-understood tree produces a confidently wrong
spec, which is worse than no spec.
