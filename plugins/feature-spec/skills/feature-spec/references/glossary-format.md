# Glossary

One file per project, at `<specdir>/GLOSSARY.md`. Written **during** the
interview, as terms resolve — never batched at the end. A term settled in round 1
and written in round 3 is a term that drifted for two rounds.

The glossary lives inside the spec directory because that is the only directory
this plugin owns. An existing project glossary elsewhere is **read and cited,
never rewritten.**

## Contents
- Which terms earn an entry
- Challenging a fuzzy term
- Entry format
- Citing rather than redefining
- The header
- Growth

## Which terms earn an entry

> **A term earns an entry if two people on the team would draw its boundary
> differently, or if the code already uses two words for it.**

| ✗ Not an entry | ✓ An entry |
|---|---|
| "Flag" — one meaning, no boundary to dispute | "Run" — the process invocation, or the logical job that survives a restart? The code uses both |
| "Timeout" — a number, defined where it is set | "Delivery" — one attempt, or the whole lifecycle of attempts? Two tables already disagree |

Three more that always earn one:

- A noun the user and the code call by **different names**. Write the entry, pick
  one, and say which loses.
- A noun that appears in a requirement and **nowhere in the code**. Either it is
  new — define it — or it is a synonym for something that exists.
- A noun the answer to a question **hinged on**. If a decision turned on what a
  word meant, that word is load-bearing.

## Challenging a fuzzy term

When a term is ambiguous, challenge it **in the round it appears**, as part of a
question rather than as a separate interrogation:

> "You said a *session* expires after 30 days. Does a session end when the
> credential expires, or when the person signs out? The code uses the word for
> both, and they behave differently on a device swap."

Never challenge more than **two terms in one round**. Vocabulary is a category in
the coverage table, not the interview's purpose, and a round that is three
definition arguments has stopped being about the feature.

## Entry format

```skeleton
## Delivery

One attempt to hand a payload to one endpoint. The lifecycle of all attempts for
one payload is a **Dispatch**, not a delivery.

- Decided: Q4 (r1)
- In code as: `webhook_deliveries` row, `Dispatcher.send`
- Not: the payload itself — that is an **Event**
```

Four fields, and the last two are what make it worth writing:

| Field | Why |
|---|---|
| The definition | one or two sentences, in the project's own vocabulary |
| `Decided:` | which question settled it, and in which round |
| `In code as:` | the type, table or function the term maps to. A term with no mapping is either new or wrong. |
| `Not:` | the nearest thing it is **not**. Boundaries are what people actually get wrong; a definition without one is a description. |

Omit `In code as:` when the term is genuinely new. Never omit `Not:` — if you
cannot name what the term is not, the term is not yet defined.

## Citing rather than redefining

If a term is already defined in a file this run read as grounding — a project
glossary, a context document, a data dictionary — **cite it with its path and
move on.**

| ✗ Redefines | ✓ Cites |
|---|---|
| "**Batch** — a group of rows processed together." (the project's own docs already define it) | "**Batch** — as defined in `docs/glossary.md`. Used here unchanged." |

Two definitions of one word is worse than none: nobody knows which is current,
and the newer file usually wins by accident rather than by decision.

When the existing definition is **wrong for this feature**, that is a finding,
not a licence to overwrite. Record it as a question, get an answer, and write the
entry as: *"`docs/glossary.md` defines this as X. Here it means Y — see Q7 (r2)."*
The disagreement is the useful part.

## The header

Every glossary opens with the same three lines:

```skeleton
# Glossary

Terms decided during feature specs in this project. External definitions are
cited, not restated: docs/glossary.md, memory-bank/
```

The external-source list is written once, in Phase 1, from whatever grounding
found. It is what stops the next run from redefining a term this run cited.

## Growth

Entries are **appended, never reordered.** Alphabetical order is tempting and
costs a full-file rewrite on every term, which is a real cost when the file is
read at the start of every future run.

An entry superseded by a later interview is struck through with a pointer to the
new one, in the same way the design record handles a superseded answer. Nothing
is deleted — a term that changed meaning is exactly the thing someone will need
to look up later.
