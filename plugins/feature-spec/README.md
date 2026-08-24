# feature-spec

**A bounded, resumable requirements interview that ends in a critic-verified
spec — and a separate command that turns that spec into a checked implementation
plan.**

Most spec tooling is a gate on the way to code, so the interview is optimised to
be *passed* rather than to be good. This one exists for the case where the spec
is the deliverable: a feature you are not building this week, a decision that
needs recording, a handoff.

It grounds itself in your repo, interviews you in capped rounds tracked against a
fixed coverage taxonomy, records the strategy you chose *and the ones you
rejected*, builds a glossary, promotes hard-to-reverse decisions to ADRs, then drafts a spec and has an independent critic score it before
anything is written.

**The interview stops at the spec, and never learns that a plan can follow it.**
That separation is load-bearing: a spec written as a gate on the way to code gets
optimised to be *passed* rather than to be good. `/feature-spec-plan` is a
downstream consumer, mentioned once in the final report and nowhere else.

Sharpest on Swift/iOS, TypeScript/React and Python. Fully functional everywhere else.

---

## Install

```
/plugin marketplace add ms-ilya/imaslov-claude-plugins
/plugin install feature-spec
```

No setup command, no config file, no dependencies on other plugins.

## Commands

| Command | Runs | Writes |
|---|---|---|
| `/feature-spec [idea] [flags]` | the whole pipeline | everything |
| `/feature-spec-grill [idea] [flags]` | interview only | design record, glossary, proposed ADRs — **not the spec** |
| `/feature-spec-write <slug>` | draft, critique, write | `spec.md`, `critique.md` |
| `/feature-spec-plan <slug>` | slice a finished spec into tasks | `plan/plan.md`, `plan/tasks/T0N.md`, `plan/plan-critique.md` |

> **`/feature-spec-grill` writes files.** It is easy to read "interview only" as
> "no side effects". It creates the spec directory and writes the design record,
> the glossary entries decided so far, and any promoted ADRs. What it
> does *not* write is `spec.md`.

**Flags:** `--fast` · `--deep` · `--resume` · `--scope <path>` ·
`--prior-art <doc.md>`.
`--fast` and `--deep` together is an error rather than a guess.

`--prior-art` covers the input the argument grammar does not otherwise model: an
analysis document that already exists. It flips Phase 1's job from *summarise
this* to *falsify this* — every claim the document makes is checked against the
code and graded confirmed, contradicted or unverifiable. A document was true when
it was written, which is not evidence it is true now.

## What it produces

```
docs/specs/<YYYY-MM-DD>-<slug>/
├── spec.md            ← the deliverable
├── tree.md            ← the design record: every answer, with its reasoning
├── critique.md        ← the critic's scored report
├── traceability.md    ← requirement → question → answer → reasoning → round
└── plan/              ← only if you run /feature-spec-plan
    ├── plan.md            ← approach, seams, milestones, generated task graph
    ├── tasks/T01.md …     ← one file per task; the only place a status lives
    └── plan-critique.md   ← the plan critic's scored report
docs/specs/GLOSSARY.md
docs/adr/…             ← only decisions that pass a three-part test
```

All of it is meant to be committed. Nothing is gitignored, and there is no
scratch directory.

**Date-prefixed, not `NNNN-`:** sequential numbering races when two branches both
create `0007-`.

## The plan stage

`/feature-spec-plan <slug>` is the only command that reads a finished spec. It
skips everything the interview already did — research, approach options, the
user picking one — and starts where a generic planner cannot: with a verified
spec, a prioritised story list, acceptance scenarios, real seams from the
grounding facts, and a bounded set of open questions.

What it adds that a task list from any agent does not:

- **The join is proved, in both directions.** Every task tags the requirements it
  covers, and `check-plan.sh` resolves each tag against `spec.md`. Forwards: a
  task claiming `FR-042` where the spec stops at `FR-009` fails as a fabricated
  citation. **Backwards — the one that matters — every identifier the spec
  defines is claimed by some task or listed under `## Not planned` with a
  reason.** A plan that silently drops a requirement reads exactly like a plan
  that covers it, and nothing but this check can tell them apart.
- **Done-conditions are quoted, never restated.** A task's `## Done when` holds
  the spec's own acceptance scenarios verbatim, and the checker looks each one up.
  Two versions of one condition drift, and the drift always favours the easier one.
- **Open questions cannot be answered by stealth.** Every `[NEEDS CLARIFICATION]`
  the spec carries is carried into the plan, and a task waiting on one is marked
  `Blocked by` it. Quietly picking a branch in an action item is the failure R20
  exists for.
- **Implementation decisions arrive labelled as decisions.** The spec states
  behaviour and names no type, library or function by design — so *every*
  technology choice in the plan is new. Each goes under `## Plan assumptions`
  with what reversing it would cost. An empty section on a real feature does not
  mean there were no assumptions; it means they are invisible.
- **Milestones are derived, not guessed.** The spec already guarantees P1 alone
  is a shippable slice, so M1 is the P1 tasks and nothing else.
- **Enabling work is legal and never silent.** A task no requirement asked for —
  extracting a seam, adding a migration — is listed under `## Enabling work` with
  what it unblocks. The rule is not *don't*; it is *say so*.
- **One status, in one place.** The task file owns its status; `plan.md`'s task
  graph is **generated** by `make-progress.sh`, and the checker fails if the two
  disagree.

An existing plan offers **replan / extend / read-only**, never a silent
overwrite. After an amendment you almost always want `extend`: a spec that gained
`FR-010` does not invalidate `T01`, and a replan that discards four completed
statuses to add one task has destroyed the only record of what was done.

**It writes the plan and stops.** No code, no `/implement`, and no estimates in
hours or days — the interview never measured one, so a number there would be
invention (R11).

## Depth modes

| Mode | Rounds | Fact-finders | Strategy phase | Critic | Roughly |
|---|---|---|---|---|---|
| `--fast` | 1 | 1 | skipped | skipped | ~5 minutes |
| default | ≤3, 4 if coverage demands it | 2 | if more than one approach is viable | 1 agent, 3 lenses | the one that should feel right |
| `--deep` | ≤5 | 4 | always | 3 parallel lenses | hard, hard-to-reverse features |

**Never more than 5 rounds in any mode.** At 25 questions the feature should have
been split, and the plugin says so rather than asking a sixth round.

`--fast` skips the picker entirely: every question arrives with a pre-accepted
recommendation and you override only what is wrong, in one reply.

### On cost

The design treats token cost as a constraint with a number rather than a
footnote — cheap model tiers for mechanical repo lookups, fixed-schema agent
returns, capped rounds, a hard cap on how many reference files can load.

**The published budget targets are engineering estimates, not measurements.**
Measuring them properly needs runs on real features with the context readout
checked before and after, which has not been done yet. The plugin will never
report a token figure to you, because it cannot count one — and a number it
cannot count would be fabrication (rule R11). Use `/context` to see the real one.

## The coverage taxonomy

Ten categories, re-scored and printed **every round**, each `Clear` / `Partial` /
`Missing` / `N/A`. It turns "exhaustive" from a feeling into a number, and gives
a stopping point that is not "the queue emptied".

Problem & outcome · Scope boundary · Behaviour & flows · Domain & data ·
Interface & platform surface · Failure & edge cases · Constraints & quality bar ·
Integration & dependencies · Verification · Vocabulary

**The number has to be honest to be worth anything**, so deferral is bounded. A
category cleared by deferral prints as `Clear*` with its count, and a
**High-impact** deferral does not clear a category at all — it holds it at
`Partial`. Otherwise "no category is Missing" would be satisfiable by deferring
the entire interview.

The *idea* of scoring against a fixed ambiguity taxonomy is spec-kit's. The
category list is this plugin's own — see Prior art.

## What makes it different

- **It survives compaction.** The design record — not the conversation — is the
  authoritative input to drafting. Every answer is written with its *reasoning*
  the moment it is given. Auto-compaction mid-interview is the failure mode that
  kills this kind of tool, and it is designed around rather than hoped against.
- **It enforces the rules you already wrote down.** It reads your `AGENTS.md`,
  `CLAUDE.md` or `.claude/rules/*.md` and checks the spec against them. It ships
  **no rules of its own and invents none.** A justified deviation is recorded
  with the rule quoted verbatim and what was considered instead — which is a far
  more useful artifact than a rule silently broken.
- **Every requirement is traceable, and the tag is resolved rather than trusted.**
  Each `FR-NNN` and `SC-NNN` carries a source tag naming the line of the design
  record it came from, and `check-spec.sh` looks every tag up in that record: a
  spec citing `Settled Q7` when the interview settled no `Q7` fails as a
  fabricated citation. Checking that a tag is merely *shaped* like a tag is the
  check a fabricated citation passes. Anything untraceable is cut or marked —
  never asserted.
- **The critic cannot rubber-stamp.** Zero blocking findings requires a list of
  what was specifically checked and found sound, citing verbatim. "Looks good" is
  not a valid return. The plan critic works the same way, against its own rubric.
- **The plan is checked against the spec, not just written from it.** Coverage is
  proved in both directions, done-conditions are quoted rather than restated, and
  the task-graph table is regenerated from the task files rather than trusted.
  See *The plan stage*.
- **It is resumable mid-interview.** `--resume` re-anchors from the record's
  protocol block, in the same session or a fresh one.
- **A checker that did not run does not read as a pass.** `check-tree.sh` and
  `check-spec.sh` check the plugin's own output, and fail loudly on an
  identifier they cannot parse rather than silently examining less of the file
  than they claim to. `check-spec.sh` refuses to run at all without the design
  record, because without it the only thing it could report is a pass it never
  established.
- **The checkers are themselves tested.** `scripts/test-checks.sh` asserts the
  shipped skeletons validate, then mutates one rule at a time and asserts that
  rule's specific failure fires — 167 assertions. A checker that silently stops
  enforcing a rule keeps printing `OK`, which is the failure mode that makes
  self-validation worse than none.
- **Validation is a hook, not a remembered step — and it knows the difference
  between incomplete and wrong.** A `PostToolUse` hook runs the right checker every
  time the design record, a draft, the plan or a task file is written. It runs
  **closed-world** checks
  only: assertions about what the file says, never about what it has not said yet.
  A record at the end of Phase 1 legitimately has four sections and no coverage
  table; a draft at write three of nine has no acceptance scenarios; a plan whose
  map was written before its tasks legitimately names tasks that do not exist yet.
  A hook that
  called those broken would not teach compliance, it would teach evasion — buffer
  everything into one unreviewable `Write`, or dodge the filename. A fabricated
  citation is wrong at every stage, so that still fires. The open-world checks run
  at the gate, where completeness is genuinely required.

## Interop

- **`memory-bank`** — no conflict by construction. This plugin writes only inside
  its own spec directory, so its glossary cannot collide with anything. An
  existing `memory-bank/`, `CONTEXT.md` or project glossary is **read** as
  grounding and cited; a term defined there is never redefined here.
- **`multi-agent-debate`** — when a strategy choice looks genuinely contested,
  the strategy phase points you at `/multi-agent-debate` rather than rebuilding
  it. A suggestion, never an automatic call.
- **`ios-quick-review` / `ios-comprehensive-review`** — downstream. They review
  code this spec eventually produces; no interaction in v1.

## Non-goals

**The spec contains no plan**, and the interview does not know one can follow it.
That is the non-goal, and it is unchanged: `spec.md` stops at what and why, with
no file-by-file change list and no task breakdown in it. *How* is a separate
document, written by a separate command, from the finished spec.

No implementation, no TDD, no `/implement` — `/feature-spec-plan` writes the plan
and stops. No issue-tracker publishing. No estimates in hours, days or story
points, at either stage. No dependency on other plugins. No config file. **No
rules of its own.**

## Known caveats

- **ADR numbering races.** When your project already numbers records
  `NNNN-`, the plugin scans for the highest and adds one — which two concurrent
  branches can both do. When it creates the directory itself it uses a date
  prefix, which does not race.
- **The interview runs at your session's model.** It has to: the grilling loop is
  a conversation, and a conversation cannot be forked away from the person having
  it. `/feature-spec-write` is a different case — it runs `context: fork`, so
  drafting has its own model and its own clean context.
- **`/feature-spec-write` cannot ask you anything.** That is the cost of the fork,
  and it is deliberate. Every path that would otherwise ask lists its options and
  stops, so you re-invoke with the answer instead of being prompted for it.
- **`--fast` has no critic.** That is the trade, and it is stated up front.
- **The plan cannot check that a task does what its tag claims.** `check-plan.sh`
  proves `T03` claims `FR-002` and that `FR-002` exists. Whether `T03`'s action
  items actually deliver `FR-002`'s behaviour is a judgement, and it is the plan
  critic's first lens rather than a script's. A tag can still hide a hole.
- **`/feature-spec-plan` has no depth modes.** One shape, one critic pass by
  default. If that proves wrong on large specs it should gain `--deep` and the
  three parallel lenses the packet script already supports.

### Self-validation

The plugin ships deterministic checkers it runs on **its own output**, rather
than trusting itself to follow the rule in prose:

| Script | Runs | Enforces |
|---|---|---|
| `scripts/check-tree.sh` | end of every round | verbatim category names, `Clear*` with its count, `N/A` with a reason, rationale and round on every answer, unique question ids, transitive deferral, **counter values that agree with the record**, **a guard state that agrees with its own counters**, **every `## Reads` entry resolving to a real file** |
| `scripts/check-spec.sh` | after drafting, before the critic | **every source in every tag resolved against the design record** — a tag may name several, and one that is merely shaped like a tag is the check a fabricated citation passes — identifier stability, an acceptance scenario per requirement, no unquantified adjectives, no bare clarification markers |
| `scripts/bump-protocol.sh` | end of every round | owns the `## Protocol` counters outright — increments them, corrects a questions count that has fallen behind the record, and **recomputes the guard from the numbers** rather than accepting a self-report. Two of its thresholds are relative to the mode, so `--deep`'s own mandate of four fact-finders and ten reference files cannot trip it before a question is asked, and the pressure counter is **lines read**, not read calls. Exit 3 means the guard just tripped |
| `scripts/check-critique.sh` | after each critic pass | the critic's shape, the `QUOTE:`/`FIX:` discipline, the anti-rubber-stamp rule, and that pass 2 accounts for every finding id pass 1 raised. Severity comes from the `BLOCKING`/`ADVISORY` section, so parallel lenses can use distinct id prefixes |
| `scripts/make-packet.sh` | Phase 6 | assembles the critic packet — statements with their tags, scenarios, coverage with `Clear*` intact, deferrals, strategy, ADR decisions, principles verbatim, the scope boundary, and the rubric inline. `--lens` emits one lens and gives it its own id prefix |
| `scripts/check-plan.sh` | after writing the plan, in a fix-until-clean loop | **every `Covers:` identifier resolved against the spec**, and **every spec identifier claimed by a task or listed under `## Not planned` with a reason** — the backwards half is the one a plan that drops a requirement fails — quoted done-conditions found verbatim in the spec, real `Touches:` and seam paths, a DAG with no cycle, legal statuses, a `Blocked` task naming its blocker, an assumption naming its reversal cost, an untagged task labelled as enabling work, and **a task-graph table that agrees with the task files** |
| `scripts/make-progress.sh` | after writing or changing any task file | owns `plan.md`'s task-graph table outright — regenerates it from the task files, which are the only place a status lives. `--check` reports staleness and changes nothing |
| `scripts/make-plan-packet.sh` | Phase 10 | assembles the plan-critic packet — what the spec asked for, its priorities and scenarios, every task with its tags and quoted conditions, the not-planned list, enabling work, assumptions, open markers, seams, the chosen strategy, principles verbatim, and the rubric inline. `--lens` emits one lens with its own id prefix |
| `scripts/make-traceability.sh` | Phase 7 | generates `traceability.md` — every requirement joined to its question, answer, reasoning and round |
| `scripts/undo-round.sh` | on request | retracts the last round — strikes its answers through (never deletes them), returns their questions to the frontier, rewinds the counters, and **marks coverage for a re-score rather than inventing the previous table** |
| `scripts/spec-diff.sh` | on an amendment | renders what actually changed: added, withdrawn, reworded under a stable identifier, and criteria whose numbers moved. The critic never sees the previous version, so `critique.md` structurally cannot show this |
| `scripts/test-checks.sh` | in development, before a release | that each of the above still fails on the mutation it exists to catch, that every `SKILL.md` frontmatter parses and follows the authoring rules, that a skill's granted scripts and named scripts are the **same list in both directions** — a script named but not granted stops the run for a permission prompt, one granted but never named is a permission nothing can reach — and that the rule table, the round cap and the guard thresholds have not drifted out of their single source. **167 assertions** |

All three checkers are run by the skill itself in a fix-until-clean loop, **and
again by a `PostToolUse` hook** on every write to the record, a draft, the plan or
a task file. A finding from any of them is not a critic finding — it is fixed
silently.

`scripts/lib/record.py` is the only parser of `tree.md`, of a drafted spec and of
a plan.
Every checker reads through it, and `test-checks.sh` asserts they still do —
because the same first-match-only tag bug once shipped in two scripts at once,
and a second parser is a second thing to keep in step with `tree-format.md`.

Counters and `## Reads` entries are checked by value, not by presence. Presence
alone made the guard unfalsifiable: a stale block could report a round the
interview never reached, and the guard reads its thresholds from exactly those
numbers.

Each refuses to report a verdict it did not reach: if `python3` is missing or the
check cannot run to completion, it exits non-zero and says so, rather than
printing a pass it never established.

### Evals

`skills/feature-spec/evals/evals.json` holds nine cases with 58 assertions, run by
the [`skill-creator`](https://github.com/anthropics/claude-plugins-official) plugin:
`evaluate my feature-spec skill with skill-creator`.

Two are **refusals** — a vague idea and a one-line change — and they are first on
purpose: a tool that cannot decline is a tool that always bills. Four more are
`--fast`, a default run on a Swift repo, a corrupted record, and an amendment
that must not renumber. Three cover `/feature-spec-plan`: a spec whose every
requirement is deferred, a full plan run, and an `extend` after an amendment
that must keep the statuses of work already done. The second-visit and
under-pressure cases are exactly where a one-off manual try never looks.

**No fixture files ship with the suite.** A spec plugin is judged on how it
interviews about a *real* codebase, and four invented sample projects would only
prove it can interview about four invented sample projects. Each case names the
kind of repo it needs and the operator points it at a real one. Where a case needs
a feature-spec artifact rather than a codebase, `test-checks.sh` already builds one
from the skeleton in `references/tree-format.md`, so it cannot drift from the
documented format.

The harness records tokens and duration per case, with and without the skill.
**That is what replaces the estimated budget numbers above with measured ones.**

## How you would know it is working

Claims are cheap; this section is the falsifiable version of the one above. The
plugin is doing its job if, over a handful of real features:

- **Specs are not amended within a week of being written.** An early amendment
  means the interview missed something a round would have caught — the coverage
  taxonomy failing at the only thing it exists for.
- **Fewer than a third of categories end `Clear*`.** Above that, the run
  converted questions into deferrals rather than into decisions, and the spec
  reads finished while being mostly open. The final report is required to say so;
  if it says so often, the tool is the problem.
- **The critic returns `fix-first` sometimes.** A critic that returns `ship`
  every single time is not a quality gate, it is a ceremony — the same failure as
  a debate where everyone agrees.
- **`--resume` is used and works.** If nobody ever resumes, the interview is
  short enough that the whole bounded-rounds apparatus is overhead.
- **You stop reaching for the interview on small features.** The refusal paths
  ("this does not need a spec") firing regularly is a sign the tool knows its own
  scope; never firing means it is being used as ceremony.
- **`## Plan assumptions` is never empty on a real feature.** The spec names no
  type or library by design, so a plan that declares no assumptions is not a plan
  without them — it is one that made them invisibly, and the honesty lens failed.
- **`extend` is used more often than `replan`.** If every amendment triggers a
  full replan, the plan is being treated as disposable, and the task statuses it
  carries were never worth anything.
- **The backwards coverage check fires at least sometimes.** A plan that never
  once drops a requirement during drafting means the check is confirming what was
  already true — worth keeping, but the interesting number is how often it
  catches one.

If none of those hold, the honest conclusion is that this is process theatre, and
the README should say so before the next person installs it.

## Prior art

Nothing here is vendored. The ideas below were reimplemented from scratch; this
section is courtesy, not a licence obligation.

| Idea | Origin |
|---|---|
| Design tree with a dependency-ordered question frontier | mattpocock `grilling` |
| Term challenge and a live glossary | mattpocock `domain-modeling` |
| The three-part ADR test | mattpocock `domain-modeling` |
| "Prefer the highest existing seam; the ideal count is one" | mattpocock `to-spec` |
| Scoring against a fixed ambiguity taxonomy; Impact × Uncertainty; `[NEEDS CLARIFICATION]`; a `## Clarifications` session log | GitHub `spec-kit` |
| Measurable, technology-agnostic success criteria; P1/P2/P3 independently-testable stories | GitHub `spec-kit` |
| Cross-artifact consistency checking | GitHub `spec-kit` |
| Per-feature directory; strategy proposal with user selection | `structured-plan-mode` |
| Per-feature plan directory with numbered task files; task metadata (goal, action items, blocked-by, execution summary) | `structured-plan-mode` |
| Cutting tasks by observable behaviour rather than by layer | common practice; stated explicitly in `references/task-slicing.md` |
| Project principles as a gate — though this plugin *reads* your file rather than generating one | GitHub `spec-kit` |
| Verbatim-citation rule; forced verdict with calibrated confidence; declared blind spot; no empty diplomacy; anti-rubber-stamp check | `multi-agent-debate` (this marketplace) |

**One thing was deliberately not taken.** `structured-plan-mode` keeps a task's
status in three places at once — the task file, the plan document and a native
task list — and asks that all three be updated together. That is three chances to
update two. Here the task file owns the status and the table is regenerated from
it, which is the same stance `bump-protocol.sh` takes with the design record's
counters: recompute, never accept a self-report.

Its phases 1–3 are also absent, because the interview already ran them: research,
2–3 approach options with trade-offs, and the user picking one are Phases 1 and 3
of `/feature-spec`, with the rejected options recorded. `/feature-spec-plan`
starts at what that skill calls Phase 4.

## Licence

MIT, as the rest of this marketplace.
