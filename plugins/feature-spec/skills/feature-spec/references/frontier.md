# The question frontier

Coverage decides **whether to keep going**. The frontier decides **what to ask
next**. Two mechanisms, two jobs — do not collapse them.

A question can sit on the frontier in a category already Clear (skip it — low
impact). A category can be Missing with nothing on the frontier (its questions
are Blocked; ask their prerequisites first). Both are normal mid-interview
states, not bugs.

## The design tree

Questions form a dependency graph, not a queue. Three buckets, all in the record:

| Bucket | Meaning |
|---|---|
| **Settled** | Answered, with rationale and round |
| **Frontier** | Every prerequisite is settled — **askable now** |
| **Blocked** | At least one prerequisite is unsettled — name it |

A question moves Blocked → Frontier the moment its last dependency settles.
Nothing else moves it.

**Deferral is transitive.** Deferring a question defers everything blocked behind
it, in one step. Never leave an orphan in Blocked pointing at a deferred parent —
it will look askable next round and it is not.

## Does this question earn a slot?

> **A question earns a slot if a different answer would change the code shape,
> the data model, or the test plan. Otherwise cut it.**

| ✗ Does not earn it | ✓ Earns it |
|---|---|
| "Should the flag be `--resume` or `--continue`?" — naming, settled at implementation | "Is resume automatic after a crash, or opt-in behind a flag?" — changes the default path and every test |
| "Should the empty state have an illustration?" — changes one view, no shape | "Who owns the draft while the sheet is open — the list or the sheet?" — changes the state graph |

Two more cuts, applied before ranking:

- **A question a fact-finder could answer is not a question.** Look it up. Asking
  the user something the repo already states is the fastest way to lose their
  trust in every other question.
- **A question whose answer you would not record is not a question.** If the
  answer would not appear in the record, you are making conversation.

## Ranking: Impact × Uncertainty

> **Impact** — how much else changes if the answer flips.
> **Uncertainty** — whether grounding already implies the answer.

Ask **high × high** first. Then high impact, then high uncertainty. Take the top
five. Never more.

**High impact and low uncertainty is not a question — it is a grounding fact you
failed to look up.** That combination is the single most common ranking error,
and it is the one the user notices.

| ✗ Mis-rated | ✓ Rated |
|---|---|
| "Which HTTP client do we use?" rated H×H — the repo has exactly one; that is a lookup | "At-least-once or exactly-once delivery?" — H×H: changes the payload, the docs and every consumer |
| "What do we name the reject table?" rated H — flipping it changes one migration | "Are rejected rows retained or dropped?" — H: changes the schema, the retention policy and the recovery path |

Rate impact from the **blast radius in the record**: how many Blocked questions
does this unblock? A question that unblocks four others outranks one that
unblocks none, almost regardless of its own weight.

## The five-question rule

**Never more than five questions in one round**, across both channels. Not four
plus "one quick extra". The cap is what makes the interview bounded, and a cap
that bends once bends every round after.

When more than five have earned a slot, the surplus stays on the frontier — it
does not become a sixth question and it is not silently dropped. It is the first
thing round *n+1* draws from.

**When fewer than five earn a slot, ask fewer.** Padding a round to five with
questions that failed the earn test is how an interview starts feeling like a
form. Three good questions and an early finish is a better round than five.

## Ordering inside the round

Ask the question whose answer unblocks the most **first**, even when a lower-rank
question is easier. The round's answers are all applied together, so the ordering
does not change what gets unblocked this round — it changes what the user reads
first, and the first question sets whether the round feels sharp or scattered.

Never ask two questions in one round where the second only makes sense given a
particular answer to the first. That is a dependency, and dependencies belong in
Blocked. Batched answers cannot resolve it.

## When the frontier empties

An empty frontier with Missing categories means the questions in those categories
are blocked behind something — say which, in the round's coverage note. An empty
frontier with no Missing categories means the interview is done: stop, do not
manufacture a round to reach the cap.
