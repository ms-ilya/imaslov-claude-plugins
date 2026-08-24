# Coverage taxonomy

Ten categories, four states, one stopping rule. Re-scored **every round** and
printed **every round**, even when nothing moved.

Two jobs, both load-bearing: it decides *whether the interview keeps going*, and
it gives the critic a definition of "complete" that is not taste.

Use the category names **verbatim**. Paraphrase one and the table stops being
comparable to itself across rounds, which is the only thing it is for.

## Contents
- The categories
- Two boundaries that are otherwise scored inconsistently
- The four states
- The stopping rule
- Scoring honestly

## The categories

| # | Category | Answers | Prevents |
|---|---|---|---|
| 1 | **Problem & outcome** | Who has the problem, what changes for them, how you would know it worked | Building the wrong thing correctly |
| 2 | **Scope boundary** | What this explicitly does *not* do; what is deliberately deferred | Scope creep discovered at implementation time |
| 3 | **Behaviour & flows** | The journeys, step by step, including the expected alternates | "It should just work" specs |
| 4 | **Domain & data** | Entities, ownership, identity, lifecycle, what persists and where | Retrofitting a data model after the surface is built |
| 5 | **Interface & platform surface** | What the caller touches, and what the platform imposes: state ownership, lifecycle, permissions, background behaviour | Discovering the platform constraint after the design is fixed |
| 6 | **Failure & edge cases** | What goes wrong, what is seen, what is retried, what is lost | The 80% demo that dies in review |
| 7 | **Constraints & quality bar** | Performance, offline, accessibility, security, privacy, compatibility floor | Unquantified adjectives shipping as requirements |
| 8 | **Integration & dependencies** | What it talks to, what it assumes exists, what breaks it | Late discovery that a dependency cannot do this |
| 9 | **Verification** | How it is tested, at which seam, what "done" is as a checkable statement | A spec nobody can prove was met |
| 10 | **Vocabulary** | Are the nouns defined and used consistently | Two names for one concept, one name for two |

The order is roughly how early each must settle. It is a guide, not a sequence —
on a feature that exists *because* of a fault, category 6 is asked first.

## Two boundaries that are otherwise scored inconsistently

- **3 vs 6.** Category 3 is the path the feature *takes* — happy path and its
  expected alternates (empty list, first run, caller cancels). Category 6 is what
  happens when something *fails*. "The user cancels" is 3. "The write fails
  halfway" is 6.
- **3 vs 5.** Category 3 is the sequence; category 5 is the surface it happens
  on. *"Then the list reorders"* is 3. *"Reorder is a drag affordance and needs
  an accessibility action"* is 5. On a command-line tool, category 5 is the flag
  surface, stdout versus stderr, and the exit codes — not nothing.

They reach different states in the same round, routinely. That is the signal
they are two categories and not one with two names.

## The four states

| State | Definition |
|---|---|
| **Missing** | No information. Not asked, not inferable from a grounding fact. |
| **Partial** | Some answers exist, but at least one decision here is unmade — *or* an answer contains an unquantified adjective. |
| **Clear** | Every decision here is made and stated in language you could hand to someone else — *or* explicitly deferred within the bound below. |
| **N/A** | The category genuinely does not apply, **with a one-line reason.** |

### Three scoring rules

> **`check-tree.sh` enforces the shape of rules 1 and 2 on every write, and
> `check-spec.sh` catches the most common adjectives in rule 3.** So do not spend
> attention self-policing the formatting — spend it on the judgement below, which
> is the part no script can make.

1. **Bounded deferral counts toward Clear.** A deliberate deferral is a decision.
   Without this, one low-value open question holds a category open forever and
   the interview never terminates.

   **The bound is the judgement:** clear-by-deferral applies only if **no deferred
   item in the category was rated High impact.** A High-impact deferral holds the
   category at **Partial**. Without the bound, deferring everything reports full
   clearance — and a coverage table that lies is worse than an interview that runs
   long. Rendering is `Clear* (2 deferred)`, everywhere, always; the script fails
   the file if the count is missing.
2. **`N/A` requires a stated reason.** *"Integration & dependencies — N/A: makes
   no network calls and reads no external data."* An unjustified `N/A` is a dodge.
3. **The unquantified-adjective scan runs every round, across all categories.**
   Any adjective whose truth you could not measure drops its category to Partial.

   The script matches a fixed word list. **The judgement is wider than the list:**
   the test is whether you could state the number that would settle it, not
   whether the word appears in a table somewhere.

   *Fails:* "the import should feel responsive." · "errors are handled
   gracefully." · "the flag is intuitive."
   *Passes:* "the import reports progress at least once every 2s." · "a failed
   row is written to the reject file with its line number." · "`--resume` with no
   checkpoint exits 0 and prints nothing."

## The stopping rule

> The interview may end when **no category is Missing**, and **no category is
> `Clear*` by a High-impact deferral.**

Partial is acceptable — Partial items ship as `[NEEDS CLARIFICATION]` markers.
Missing means a whole dimension was never considered, which is not the same
thing and is not shippable.

The second clause is what stops the stopping rule from being satisfiable by
deferring everything.

**When more than a third of categories end as `Clear*`, say so plainly in the
final report:** *"most of this spec is open questions — consider another round,
or a narrower feature."* Reporting it is not optional. A `Clear*`-heavy spec
that reads as finished is the failure this taxonomy exists to prevent.

Round caps and the context guard override the stopping rule in both directions.
When they end an interview with Missing categories, those categories ship as
`[NEEDS CLARIFICATION]` at section level and the final report says so.

## Scoring honestly

The failure mode is not mis-scoring, it is **copying last round's table and
nudging one row.** Two habits prevent it:

- Score each category by naming the decision that is still unmade. If you cannot
  name one, it is not Partial — it is Clear.
- A category that has not moved in two rounds is either blocked behind a
  dependency (say which) or genuinely done (score it Clear). "Still Partial" with
  no reason for a third round is a scoring failure, not a coverage finding.
