# Round format

A round is **one `AskUserQuestion` call plus one markdown block.** They render
differently and have different limits, and only one of them shows your prose.
Writing a round as if it were all markdown is the mistake this file prevents.

The format is deliberately invariant. A round looks identical whether the feature
is a screen, a service or a migration — form fixed, content free.

## Contents
- The two channels
- The field mapping
- Ten channel rules
- Content discipline
- Round layout, in order
- Facts before the round, never during it
- How round 2+ differs

## The two channels

| | **Channel A** — `AskUserQuestion` | **Channel B** — markdown |
|---|---|---|
| Carries | closed questions, 2–4 mutually exclusive answers | open questions, grounding recap, coverage table, the offer |
| Rendered as | a picker — **surrounding markdown is not shown** | the assistant message |
| Hard limits | ≤4 questions per call, 2–4 options each | none |
| Per question | `header` ≤12 chars · `question` prose · `multiSelect` · `options[]` | free |
| Per option | `label` 1–5 words · `description` prose | free |
| Always added | an **"Other"** option, automatically | — |

**≤5 questions per round across both channels.** Four closed plus one open is the
usual shape. Five open is legal; five closed is not — the picker caps at four.

## The field mapping

```skeleton
header:      "Trigger"                     ← ≤12 chars, renders as a chip
question:    "What starts a retry?
              Why it matters: it decides whether retry state lives in the row or
              in a queue, which changes the schema."
multiSelect: false
options:
  - label:       "Periodic sweep (Recommended)"
    description: "No new infrastructure, and the table is already the source of
                  truth for delivery state."
  - label:       "In-process timer"
    description: "Lowest latency; lost on restart."
  - label:       "External queue"
    description: "Most durable; adds a dependency this service does not have."
```

Three consequences that are easy to lose:

1. **"Why it matters" goes inside `question`.** A separate line above the call is
   never displayed. This is the single most likely way to lose the rule.
2. **The recommendation is the first option, with `(Recommended)` appended to the
   label** — not bolded prose, not a sentence afterwards. Labels are 1–5 words,
   so the *reason* lives in `description`.
3. **"Other" always exists.** Design for it: an Other answer is recorded verbatim
   as the decision. If it raises a new question, that question joins the frontier
   for the next round — it never reopens this one.

`multiSelect: true` is right for exactly one shape: *"which of these are in
scope?"* A multi-select on a genuine either/or produces an unanswerable spec.

`preview` is single-select only and renders monospace, side by side. It is wasted
on interview questions and it is exactly right for **strategy selection**, where
the user compares shapes rather than answering a question. Blocks are ≤12 lines
and show *shape*, never full code — a preview long enough to be an
implementation has stopped comparing and started prescribing.

## Ten channel rules

1. ≤5 questions per round, split across the channels. ≤4 in the picker.
2. **One `AskUserQuestion` call per round, never two.** Two pickers is hostile.
3. `header` ≤12 characters. It is a chip, not a summary.
4. `label` is 1–5 words; the reason lives in `description`.
5. The recommended option is first, `(Recommended)` appended to its label.
6. "Why it matters" is appended to the `question` field. Anywhere else it is not
   rendered.
7. `multiSelect: true` only for "which of these are in scope".
8. `preview` never appears in the interview — only in strategy selection.
9. "Other" always exists. Record an Other answer verbatim as settled.
10. **If `AskUserQuestion` is unavailable, the whole round renders as Channel B**
    as one numbered block. The cap and the content rules do not change. Never
    fail on it.

## Content discipline

**Every question carries a recommendation, and every recommendation cites
something.** The repo, a stated constraint, or a named trade-off.

| ✗ Ungrounded | ✓ Grounded |
|---|---|
| "Recommended: idempotent writes — it's best practice." | "Recommended: idempotent writes — every row already carries a stable source id, so dedupe costs one index." |
| "Recommended: MVVM — it's the standard pattern." | "Recommended: keep state on the parent — the two sibling screens already do, and the diff stays in one file." |

**Every question names what the answer changes** — a file, a shape, a schema, a
test. Never "this is important".

| ✗ Generic | ✓ Names the change |
|---|---|
| "Why it matters: this is an important architectural decision." | "Why it matters: it decides whether retry state is a column on the existing row or a new queue — a migration either way, but a different one." |
| "Why it matters: it affects the user experience." | "Why it matters: it decides whether progress goes to stdout, which makes the tool unpipeable, or to stderr, which does not." |

## Round layout, in order

1. **Grounding block** — round 1 only, under ten lines: what was found, with
   paths, and **what it made unnecessary to ask.** Round 2+ replaces it with a
   one-line recall of any *new* facts, or nothing.
2. **Header** — `Round n of m`, plus a one-line warning that a picker follows. A
   picker arriving with no preamble reads as an interruption.
3. **Channel A** — the picker.
4. **Channel B** — open questions, numbered, each with a suggestion and a
   why-it-matters.
5. **The offer** — `skip` defers a question; `stop` ends the interview and drafts
   from what exists. Offered **every round**, not once at the start. That is the
   difference between a bounded interview and an interrogation.
6. **Coverage table** — printed every round even when nothing moved, with a line
   explaining anything that did not move.

**No preamble, no praise.** The round opens on the grounding block or on Q1.

## Facts before the round, never during it

It is not mechanically possible to hold a user prompt open while agents run. A
fact needed for a question must be found **before** the round is rendered. A fact
that turns out to be needed mid-round becomes a grounding task for the *next*
round — never a pause in this one.

## How round 2+ differs

Only three things: no grounding block; questions may reference settled answers by
number (*"given Q2 → shared in-flight work, what should a second caller see if it
fails?"*); and the coverage table's "Was" column holds the previous round's
values.

The header, the cap, the two channels, the recommendations, the why-it-matters
discipline and the `skip`/`stop` offer are identical every round. **The format
does not evolve.**
