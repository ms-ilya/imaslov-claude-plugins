# feature-spec

**A bounded, resumable requirements interview that ends in a critic-verified
spec — and deliberately stops there.**

Most spec tooling is a gate on the way to code, so the interview is optimised to
be *passed* rather than to be good. This one exists for the case where the spec
is the deliverable: a feature you are not building this week, a decision that
needs recording, a handoff.

It grounds itself in your repo, interviews you in capped rounds tracked against a
fixed coverage taxonomy, records the strategy you chose *and the ones you
rejected*, builds a glossary, promotes hard-to-reverse decisions to ADRs, then drafts a spec and has an independent critic score it before
anything is written.

Sharpest on Swift/iOS. Fully functional everywhere else.

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

> **`/feature-spec-grill` writes files.** It is easy to read "interview only" as
> "no side effects". It creates the spec directory and writes the design record,
> the glossary entries decided so far, and any promoted ADRs. What it
> does *not* write is `spec.md`.

**Flags:** `--fast` · `--deep` · `--resume` · `--scope <path>`.
`--fast` and `--deep` together is an error rather than a guess.

## What it produces

```
docs/specs/<YYYY-MM-DD>-<slug>/
├── spec.md        ← the deliverable
├── tree.md        ← the design record: every answer, with its reasoning
└── critique.md    ← the critic's scored report
docs/specs/GLOSSARY.md
docs/adr/…         ← only decisions that pass a three-part test
```

All of it is meant to be committed. Nothing is gitignored, and there is no
scratch directory.

**Date-prefixed, not `NNNN-`:** sequential numbering races when two branches both
create `0007-`.

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
- **Every requirement is traceable.** Each `FR-NNN` and `SC-NNN` carries a source
  tag naming the line of the design record it came from. Anything untraceable is
  cut or marked — never asserted.
- **The critic cannot rubber-stamp.** Zero blocking findings requires a list of
  what was specifically checked and found sound, citing verbatim. "Looks good" is
  not a valid return.
- **It is resumable mid-interview.** `--resume` re-anchors from the record's
  protocol block, in the same session or a fresh one.
- **A checker that did not run does not read as a pass.** `check-tree.sh` and
  `check-spec.sh` check the plugin's own output, and fail loudly on an
  identifier they cannot parse rather than silently examining less of the file
  than they claim to.

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

No implementation, no TDD, no task breakdown, no `/implement`. No issue-tracker
publishing. No dependency on other plugins. No config file. **No rules of its
own.**

## Known caveats

- **ADR numbering races.** When your project already numbers records
  `NNNN-`, the plugin scans for the highest and adds one — which two concurrent
  branches can both do. When it creates the directory itself it uses a date
  prefix, which does not race.
- **The spec is drafted at your session's model.** The interview and the drafting
  run in the main conversation, and a plugin cannot switch that. Only the
  fact-finder and the critic run at chosen model tiers.
- **`--fast` has no critic.** That is the trade, and it is stated up front.

### Self-validation

The plugin ships two deterministic checkers it runs on **its own output**, rather
than trusting itself to follow the rule in prose:

| Script | Runs | Enforces |
|---|---|---|
| `scripts/check-tree.sh` | end of every round | verbatim category names, `Clear*` with its count, `N/A` with a reason, rationale and round on every answer, unique question ids, transitive deferral |
| `scripts/check-spec.sh` | after drafting, before the critic | a valid source tag on every requirement and criterion, identifier stability, an acceptance scenario per requirement, no unquantified adjectives, no bare clarification markers |

Both are run by the skill itself in a fix-until-clean loop. A finding from either
is not a critic finding — it is fixed silently.

Each refuses to report a verdict it did not reach: if `python3` is missing or the
check cannot run to completion, it exits non-zero and says so, rather than
printing a pass it never established.

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
| Project principles as a gate — though this plugin *reads* your file rather than generating one | GitHub `spec-kit` |
| Verbatim-citation rule; forced verdict with calibrated confidence; declared blind spot; no empty diplomacy; anti-rubber-stamp check | `multi-agent-debate` (this marketplace) |

## Licence

MIT, as the rest of this marketplace.
