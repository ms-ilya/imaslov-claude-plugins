# Degradation

Every row is a real path a first-week user hits. Unspecified failure behaviour is
where prompt-driven tooling gets embarrassing.

| Situation | Behaviour |
|---|---|
| Not a git repo, or empty | Works. No source files and no `docs/` → say "no existing code to ground in — questions will be broader." |
| Huge repo, no `--scope` | The agent caps its own reads and returns `NOT_FOUND`. Suggest `--scope` for next time. |
| A document the user passed cannot be opened | Name it, leave it out and carry on. Its contents are unknown: no decision and no fact comes from it. |
| Fact-finder returns nothing useful | The question it was meant to collapse becomes a normal interview question. Never fabricate. Never retry more than once. |
| Fact-finder errors or times out | Continue. Note `(fact-finding failed)` in `## Grounding facts`. Never block. |
| Idea too vague to slug | Ask one clarifying question, then stop. An unformed idea needs an interview before it needs a spec: say so, and name `/grill-me` as the tool for that. A suggestion, never a call. |
| User contradicts an earlier answer | Show both, ask which holds, record the change with its reason. Never silently overwrite. |
| User abandons mid-round | `tree.md` already holds every prior answer (R1). `--resume` returns to the same frontier. |
| `tree.md` unparseable | Run `check-tree.sh <tree.md> --doctor`, which names every missing section and prints the heading to restore. Restore headings only: what a section held comes back from the input or the user, never from the format's example. If that does not repair it, copy the file to `tree.archived-<date>.md` and restart. Never guess at a corrupted design record. |
| Critic still blocking after two passes | Publish anyway. The critique files carry the unresolved findings and the report says so. |
| Critic returns nothing, or not in the shape | Send what `check-critique.sh` printed back to the same critic once. If the reply fails again, publish without a critique and say so. A finding whose quote is not in the packet is never acted on. |
| `check-spec.sh` or `publish-spec.sh` will not go clean after three attempts | Stop. Leave `spec.draft.md` in place, report the findings as printed, and say the run can be picked up with `--resume`. Never edit around a checker to silence it. |
| No stack layer matches | Layers ship for Swift, TypeScript and Python. On anything else none loads: generic questions, and no apology for their absence. |
| Scope spans two stacks | Ask which side the feature lives on, once, before dispatching. One question saves a round aimed at the wrong stack. Never load two layers. |
| `AskUserQuestion` unavailable | The whole round renders as one numbered markdown block. Caps and content rules unchanged. Never fail on it. |
| User picks **"Other"** | Record the free text verbatim as the decision. A new question it raises joins the frontier for the **next** round. |
| Existing spec root from another tool | Adopt the location, write only your own `<date>-<slug>/` inside it, never touch a sibling directory (R17). |
| A one-line change with no decisions in it | Say so and stop: "this does not need a spec — there is nothing here a spec would decide." If the user disagrees, they say so and the run goes on. |
| A `spec.draft.md` is already there | On `--resume` it is the draft to continue from, once `check-spec.sh` has passed on it. On any other run it is left over from one that stopped before publishing: say so in one line and overwrite it at drafting. It is never treated as a spec, and a new draft is never written from it. |
| `tree.md` past 400 lines | Move superseded `## Settled` entries to `## History`. Nothing is deleted. |

## The rule behind the table

Every row degrades toward **producing something**. A round can be cut short,
a fact can be missing, the critic can stay unhappy — none of those stop a spec
being written and none of them are papered over silently.

The two rows that are not degradations but refusals — an idea too vague to slug,
and a one-line change with no decisions in it — both stop *before* creating
anything. Refusing to start is cheap; abandoning halfway is not.

No row tells you to delete or move a file. This plugin's grants cover reading,
writing and its own scripts; a file in the way is copied, overwritten or left,
and said so.
