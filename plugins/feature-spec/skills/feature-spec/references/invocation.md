# Invocation — input, arguments and intake

Loaded in Phase 0, once.

It lives here rather than in the skill body because it is read exactly once: what
it resolves is written into the record's `## Protocol` block, and every later
step re-anchors from there.

**After a compaction, do not reload this file.** `## Protocol` in `tree.md`
already carries the slug, the round and the next phase.

## Contents
- What the user can pass
- How much gets asked
- Intake: reading what the user passed
- Grading a document's claims

---

## What the user can pass

`$ARGUMENTS` is free text: an idea in words, any number of paths to documents, or
both. There are two flags, `--resume` and `--scope <path>`.

In order:

1. Extract the flags. A `--token` that is neither of the two belongs to the
   idea: "add a `--json` flag" is a sentence, not an option.
2. Every path in what remains that names an existing **document** — a brief,
   notes, an analysis, something written for a reader — is an input document.
   Say which ones you found, and which paths point at nothing: a document you
   could not open contributes no decision and no fact, and its contents are not
   guessed at. A path to source code is the thing being changed: read it for
   facts, not for decisions.
3. If what remains is a single word that matches an existing slug, treat it as
   one. Directories are date-prefixed, so resolve by glob `*-<slug>`: one match
   proceeds; several are listed for the user to pick; none falls through to 4.
   Amend reuses the matched directory and never re-dates it.
4. Otherwise the words are the feature idea. The slug is two to five words
   that name the feature, without paths or flags. With documents and no words,
   take it from the main document's file name, minus any date prefix. The
   directory is `<date>-<slug>`, and that full name is what `## Protocol`
   records.
5. Nothing at all and no `--resume` → list the existing slugs, ask for an idea or
   a document, and stop.
6. `--resume` continues an unfinished run: a `<specdir>` that holds a `tree.md`
   and no `spec.md`, or a `spec.draft.md` beside an older `spec.md`. With no
   slug, take the only unfinished run; when there are several, list them and ask.
   Re-read `tree.md`, re-anchor from `## Protocol`, and re-enter at `Next phase`.
   A `spec.draft.md` already there is the draft to continue from at Phase 6 or 7;
   run `check-spec.sh` on it before trusting it. Where the run is finished there
   is nothing to resume; fall through to the amend / restart / read-only choice.
7. `--scope <path>` confines grounding to one directory.

## How much gets asked

Often nothing. Phase 2 decides from the record, not from a setting: input that
leaves no category Missing and nothing high-impact open gets no round at all.

When something is open, a session runs at most two rounds of at most five
questions (R9). A session that amends an existing record gets two more, numbered
on from where the record stopped, which is what `Round: n of m` records.

A long document does not raise that ceiling. It lowers the number of questions
worth asking, because most of them are now answered by the document or checkable
by a fact-finder (R8).

## Intake: reading what the user passed

The input is usually not an unformed idea. It is a brief from an interview, a
findings write-up, a migration plan, a design note someone wrote last month, or
the user's own paragraph. All of it is read the same way.

Sort every statement that a requirement could depend on into one of three:

| It is | Then |
|---|---|
| **A decision the user made** | a `## Settled` entry tagged `(r0)`. The answer is the input's own wording, not a summary of it. Its `*Why:*` ends with the document's path as `## Reads` lists it and the section (`From docs/briefs/retry.md, "Decided".`), or with "Stated in the request.", and it carries a `[P1]`–`[P3]` tag if the input ranks it |
| **A claim about the repository** | a line for a fact-finder to grade, then a `## Grounding facts` entry with its verdict |
| **An assumption, a guess or an open question** | a `## Frontier` entry. It is not settled because someone wrote it down |

Some documents do the sorting for you: a brief with separate "Decided", "Assumed"
and "Open questions" sections maps straight across. Its "Out of scope" list is a
set of scope decisions, and its goal and done-condition are decisions too. Facts
it lists are claims to grade. A risk or a spike is neither a decision nor a fact:
it becomes an open question when a requirement depends on how it turns out. A
Q&A log is where the decisions came from, not a second set of them. A decision
about how to build it — a library, where the code lives, a pattern to follow —
is the user's decision like any other: settle it `(r0)`, and the spec lists it
as an implementation constraint. When the
input ranks slices rather than single decisions, every user-visible decision in a
slice takes that slice's priority. A decision the input puts in no slice, or in
two, carries no priority tag: which slice it belongs to is not yours to pick. A document that mixes the three needs your
judgement. When you cannot tell whether the user decided something or the author
guessed it, and a requirement depends on it, that is a question for Phase 2.

Four things not to do:

- **Do not paraphrase a document into `## Problem`.** One line, in the user's
  words, with a `## Reads` entry naming the document so drafting can open it.
- **Do not promote an assumption.** A spec built on a bet nobody confirmed reads
  exactly like one built on a decision.
- **Do not reword a decision.** The `(r0)` entry is what every requirement is
  later compared with. Copy the sentence that decides; trim around it if you
  must, and add nothing. A scope item that is only a noun phrase stays one, and
  the entry's title says it is a scope boundary. `check-tree.sh` compares each
  answer with the document its `*Why:*` names and fails one that is mostly not
  that document's words.
- **Do not re-ask what the input settled** (R8). Showing the user their own
  decision as a question is the fastest way to lose the round.

## Grading a document's claims

A document is a claim about the repository, and it was true when it was written.
Every fact in it is still true, no longer true, or was never checkable, and which
of the three cannot be known without looking.

| | Question from the run | Claim from a document |
|---|---|---|
| The fact-finder answers | what the run needs to know | **what the document says is so** |
| A `## Grounding facts` entry reads | `<fact> (fact-finder, r0, high)` | `<claim> — confirmed at path:line (fact-finder, r0, high)` |

Grade every claim checked, and record which:

| Verdict | Means | What it does to the run |
|---|---|---|
| **confirmed** | the document said it and the code agrees, cited at `path:line` | the claim can be built on. Confirmation is information; record it |
| **contradicted** | the code says otherwise | the most valuable result of the phase. It becomes a question, or a correction to `## Problem` |
| **unverifiable** | about intent, history or something outside the repository | not a fact. If a requirement would depend on it, it is a question |

A claim the repository refutes by absence — the file, the helper or the pipeline
it names is not there — is **contradicted**, and the fact says what was searched.
The other two verdicts are written the same way as a confirmation:
`<claim> — contradicted: <what the code does>, path:line` and
`<claim> — unverifiable: <why>`.

A fact-finder's report is a report. Before a contradiction reaches the user,
open the line it cites and read it: telling someone their document is wrong is
the one finding of this phase that has to be right. Every `path:line` that goes
into the record is opened again by `check-tree.sh`, which fails one that points
at no file or past the end of one.
