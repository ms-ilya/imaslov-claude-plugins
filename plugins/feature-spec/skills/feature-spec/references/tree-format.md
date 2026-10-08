# `tree.md` — the design record

`tree.md` is the **sole authoritative input to drafting.** Not a bookmark, not a
log — the record. Everything the spec says must be traceable to a line in it.

Written to at intake and after every round, before anything else (R1). What is
held only in the conversation does not survive compaction; the file does.

## Contents
- The skeleton
- What each section is for
- Rules the format depends on
- When the file will not parse

## The skeleton

```skeleton
# Design tree: <feature name>

## Problem
One line, in the user's own words, corrected in round 1: batch imports restart
from zero after a crash, and a large import can take longer than the window
between crashes.

## Protocol
Slug: 2026-08-21-retry-uploads   Started: 2026-08-21
Stack: none   Scope: cmd/ingest
Round: 1 of 2   Next phase: 2

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
| Constraints & quality bar | Clear* (1 deferred) |
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
  *Why:* one source of truth, and replay already reads it. Stated in the request. (r0)
- **Q2 Attempt ceiling** → at most 5 attempts spread over 24h. [P2]
  *Why:* survives a workday outage, bounds file growth. (r1)

## Frontier (askable now)
- **Q7 What a partial batch does on resume** — deps: Q1 ✔ — impact H, uncertainty H

## Blocked
- **Q9 Operator-visible failure surface** — deps: Q7

## Deferred → ships as [NEEDS CLARIFICATION]
- **Q12 Per-source overrides** — low impact, decided post-launch (r1)

## Strategy
- Chosen: B — sweep the checkpoint on a timer, one in-flight batch.
- Rejected: A (retry inline, blocks ingest); C (external queue, new dependency).

## Glossary written
- Batch, Checkpoint, Attempt

## Promoted to ADR
- ADR-0004 Checkpoint file over a database for retry state — Proposed

## Sessions
- 2026-08-21 r0–r1 (initial)

## History
Superseded ## Settled entries land here. Drafting does not read this section.
```

## What each section is for

| Section | Job | Written |
|---|---|---|
| `## Protocol` | Re-anchors the **process** after a compaction or in a later session, exactly as the rest re-anchors the **answers**: which round was last answered, and which phase comes next. | at intake, then at the end of every round and phase |
| `## Problem` | One line: whose problem, and what changes. Written at intake from the user's own words, corrected when a round shows it was wrong. Without it, drafting invents the problem statement — the single worst thing for it to invent. | Phase 1 |
| `## Reads` | The tree declares its own dependencies. Drafting opens `tree.md` plus exactly these files and nothing else. Every entry is a file that exists: a glossary that has not been written yet is not listed. | Phase 1, appended as the glossary and ADRs are written |
| `## Coverage` | Whether any clarifying round is needed, and whether another is. Category names are the taxonomy's **verbatim** — paraphrase them and the table stops being comparable to itself. | scored before the first round, re-scored after every round |
| `## Principles in force` | The repo's own rules, quoted. The critic enforces these, never its own taste. | Phase 1 |
| `## Grounding facts` | Numbered, each citing its `path:line` from the repository root, or saying what was searched when the fact is that something is absent, and ending with source, round and confidence: `(fact-finder, r0, high)`, or `(read at intake, r0, high)` for what you read yourself. Numbers are the source-tag target. | Phase 1 |
| `## Settled` | Decision **and rationale**, plus a `[P1]`/`[P2]`/`[P3]` tag where it describes user-visible behaviour. The rationale is the part a compaction destroys and the part the spec cannot be written without. | at intake `(r0)`, then every round |
| `## Frontier` / `## Blocked` | What is askable now versus what is dependency-blocked. Two lists, not one. | before the first round, then every round |
| `## Deferred` | Bounded, with a reason and the round. Each becomes a `[NEEDS CLARIFICATION]` marker. | every round |
| `## Strategy` | Chosen **and rejected**, with reasons. The rejected list is what stops the same argument recurring in three months. | Phase 3 |
| `## Glossary written` / `## Promoted to ADR` | Pointers into files that live elsewhere. Titles only — the content is in the file. | Phases 2 and 4 |
| `## Sessions` | One line per session. Amendment appends; it never rewrites. | every session |
| `## History` | Overflow only. Not read when drafting. | on the 400-line rule |

## Rules the format depends on

1. **Question identifiers never repeat and never renumber.** `Q7` means one
   question for the life of the file, wherever it has moved to.
2. **Every `## Settled` entry carries its round.** `(r1)` is what makes an
   answer's age legible after an amendment. **`(r0)` is a decision the user made
   before any round** — in the request, a brief or another document they passed
   in. Its answer keeps the input's wording, and its `*Why:*` ends with where it
   came from: the document's path as `## Reads` lists it and the section, or
   "Stated in the request." Every requirement that cites the entry is compared
   with this text, so a paraphrase here is a new decision nobody made, and the
   checker fails an answer that is mostly not the named document's words.
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
7. **Priority comes from the user, never from drafting.** An answer about
   user-visible behaviour carries `[P1]`, `[P2]` or `[P3]`, where **P1 alone is
   a shippable slice.** Drafting assigns no priority the tree does not hold — a
   priority invented at drafting time is a decision the user never made.
8. **A number that a success criterion will be built on lives in the answer, not
   the rationale.** *"at most 5 attempts spread over 24h"* is an answer; *"a
   sensible ceiling"* with the number buried in the `*Why:*` is not. The
   unquantified-adjective scan exists to force the number in at the moment the
   answer is given, when the user is there to supply it.
9. **`## Problem` is one line and it is never blank.** An idea too vague to
   state in one line stops the run in Phase 0, before a record exists.
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

12. **An assumption is not a decision.** Input carries bets alongside decisions:
    a brief's "Assumed" list, a "probably" in a note, an open question someone
    wrote down. Only what the user decided enters `## Settled`. The rest goes to
    `## Frontier`, and to `## Deferred` if no round settles it. A default you
    showed the user in a round and they let stand is a decision, recorded with
    that round and "default, not contested" in its `*Why:*`. A default they never
    saw is not.
13. **`Round: n of m` counts clarifying rounds answered.** `0` is legal and is the
    normal value when the input needed no interview. `m` is the ceiling for this
    session: two more than the round the session started from, so a first
    session reads `of 2` and an amendment of a record at round 2 reads `of 4`.
    `Next phase` stops at `7`. A finished run is told by its files: `spec.md`
    with no `spec.draft.md` beside it.

14. **`Slug:` holds the directory name**, date included:
    `2026-08-21-retry-uploads`. The bare slug is what follows the date. `Stack:`
    and `Scope:` read `none` when no layer loaded and no `--scope` was given.
15. **A required section with nothing in it keeps its heading and stays
    empty.** The gate needs the heading. A filler sentence under it reaches the
    critic as though the project had written it, and the packet already says so
    when a section is empty. `## Strategy`, `## Glossary written`,
    `## Promoted to ADR` and `## History` are not required: leave each out until
    it has something in it.
16. **A grounding fact cites a line that was opened.** The citation is a
    backticked `path:line`, the path as it is on disk from the repository root;
    a bare `` `:349` `` after it points into the same file. `check-tree.sh`
    opens every one. A citation of a file that is not there, or of a line past
    the end of the file, fails for a fact of this session and is reported for
    an older one, whose code may have moved since.
17. **A graded claim says its verdict after a dash:**
    `<claim> — contradicted: <what the code does>, path:line` or
    `<claim> — unverifiable: <why>`. A requirement may cite a contradicted claim
    for what the code was found to do. An unverifiable one is not a fact and
    cannot be cited at all.
18. **An entry is one bullet in one shape.** `- **Q<n> Title** → answer` under
    `## Settled`, `- **Q<n> Title** — reason (rN)` under `## Deferred`. An entry
    written any other way looks settled to a person and does not exist for any
    tool, so the checker fails it.

## When the file will not parse

Run `check-tree.sh <tree.md> --doctor`. It names each missing section and prints
the heading to restore. Restore the heading only: what the section held comes
back from the input or from the user, never from the example above, which is
about another feature. If the record cannot be repaired that way, say which
section failed, offer a restart and stop. A half-understood record produces a
confidently wrong spec, which is worse than no spec.
