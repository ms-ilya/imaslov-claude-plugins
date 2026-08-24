# Degradation

Every row is a real path a first-week user hits. Unspecified failure behaviour is
where prompt-driven tooling gets embarrassing.

| Situation | Behaviour |
|---|---|
| Not a git repo, or empty | Works. No source files and no `docs/` → say "no existing code to ground in — questions will be broader." |
| Huge repo, no `--scope` | The agent caps its own reads and returns `NOT_FOUND`. Suggest `--scope` for next time. |
| Fact-finder returns nothing useful | The question it was meant to collapse becomes a normal interview question. Never fabricate. Never retry more than once. |
| Fact-finder errors or times out | Continue. Note `(fact-finding failed)` in `## Grounding facts`. Never block. |
| Idea too vague to slug | Ask one clarifying question, then stop. Do not open a 3-round interview on an unformed idea. |
| User contradicts an earlier answer | Show both, ask which holds, record the change with its reason. Never silently overwrite. |
| User abandons mid-round | `tree.md` already holds every prior answer (R1). `--resume` returns to the same frontier. |
| `tree.md` unparseable | Run `check-tree.sh <tree.md> --doctor`, which names every broken section and prints its repair straight from the shipped skeleton. Apply what it prints, re-check, and continue. If it is beyond repair, archive to `tree.archived-<date>.md` and restart. Never guess at a corrupted design record. |
| Critic still blocking after two passes | Write anyway. `critique.md` carries the unresolved findings and Phase 7 says so. |
| No stack layer matches | Layers ship for Swift, TypeScript and Python. On anything else none loads: generic questions, and no apology for their absence. |
| Scope spans two stacks | Ask which side the feature lives on, once, before dispatching. One question saves a round aimed at the wrong stack. Never load two layers. |
| `AskUserQuestion` unavailable | The whole round renders as one numbered markdown block. Caps and content rules unchanged. Never fail on it. |
| User picks **"Other"** | Record the free text verbatim as the decision. A new question it raises joins the frontier for the **next** round. |
| Existing spec dir from another tool | Adopt the location, write only your own `<date>-<slug>/` inside it, never touch a sibling directory (R17). |
| A one-line change with no decisions in it | Say so and stop: "this does not need a spec — there is nothing here a spec would decide." Suggest `--fast` if the user disagrees. |
| A stale `spec.draft.md` is present at the start of a run | It is the residue of a run that died between drafting and writing. Delete it and say so in one line. Never treat it as a spec, and never draft from it — the design record is the input, not a previous draft. |
| `tree.md` past 400 lines | Move superseded `## Settled` entries to `## History`. Nothing is deleted. |

## The rule behind the table

Every row degrades toward **producing something**. The interview can end early,
a fact can be missing, the critic can stay unhappy — none of those stop a spec
being written and none of them are papered over silently.

The two rows that are not degradations but refusals — an idea too vague to slug,
and a one-line change with no decisions in it — both stop *before* creating
anything. Refusing to start is cheap; abandoning halfway is not.
