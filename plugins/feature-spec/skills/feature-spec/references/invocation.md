# Invocation — modes, arguments and the round cap

Loaded in Phase 0, once, by `feature-spec` and `feature-spec-grill`.

It lives here rather than in the skill body because it is read exactly once and
never again: the mode and the cap are written into the record's `## Protocol`
block the moment Phase 0 resolves them, and every later round re-anchors from
there rather than from this file. Anything the run needs *late* belongs in the
skill; this is the opposite.

**After a compaction, do not reload this file.** `## Protocol` in `tree.md`
already carries the slug, the mode, the round and the cap. That is what it is for.

---

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

1. Extract flags: `--fast`, `--deep`, `--resume`, `--scope <path>`,
   `--prior-art <path>` (repeatable).
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
7. A path in the free text that names an existing markdown document is
   **prior art**, not a feature idea. Treat it as `--prior-art` and say so.

---

## Prior art — when the input is a document, not an idea

The argument grammar above assumes an unformed idea. That is not the common
case. The common case is **a large analysis document that already exists** — a
findings write-up, a migration plan, a design note someone wrote last month —
and the interview is being run to turn it into a spec.

Naming such a document with `--prior-art <path>` changes exactly one thing, and
it is the thing that matters:

> **Phase 1's job becomes *falsify this document*, not *summarise it*.**

A document is a claim about the repository, and it was true when it was written.
Every fact in it is either still true, no longer true, or was never checkable —
and which of the three it is cannot be known without looking. Trusting it silently
imports last month's repository into this month's spec.

| | Ordinary input | Prior art |
|---|---|---|
| Fact-finders answer | questions the interview needs | **claims the document makes** |
| A `## Grounding facts` entry reads | `<fact> (fact-finder, r0, high)` | `<claim> — confirmed at path:line (fact-finder, r0, high)` |
| The valuable result | facts that remove questions | facts that remove questions, **and every claim graded** |

Grade every claim you check as one of three, and record which:

| Verdict | Means | What it does to the interview |
|---|---|---|
| **confirmed** | the document said it and the code agrees, cited at `path:line` | the claim can be built on. Confirmation is information — record it. |
| **contradicted** | the code says otherwise | **the highest-value output of the whole phase.** It becomes a question, or a correction to `## Problem`. |
| **unverifiable** | about intent, history or something outside the repo | not a fact. If a requirement would depend on it, it is a question. |

**Do not paraphrase the document into `## Problem`.** One line, in the user's
words, as always — with a `## Reads` entry naming the document so drafting can
open it.

**A large document does not raise the round cap.** It lowers the number of
questions worth asking, because most of them are now answerable by a
fact-finder — which is R8, applied to a bigger surface.

---

# Phases
