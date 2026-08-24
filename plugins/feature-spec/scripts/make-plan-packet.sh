#!/usr/bin/env bash
# ABOUTME: Assembles the Phase 10 critic packet from the plan, its task files, the spec and the record —
# ABOUTME: so no lens is blinded by a hand-rolled extraction, and the rubric arrives inline.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: make-plan-packet.sh <plan-dir> --spec <spec.md> --tree <tree.md> [--lens <name>] [--out <path>]

  Prints the plan-critic packet on stdout, ready to paste into the dispatch.
  NOT the whole plan: prose doubles the phase's cost, and a lens that seems to
  need it is a sign the packet is wrong.

  --lens <name>  coverage | sequencing | honesty
                 Emits only that lens's rubric section and gives the lens its
                 own finding-id prefix. Use when lenses run in parallel and
                 would otherwise all number their findings B1.
  --out <path>   Write to a file instead of stdout. Pass - for stdout.

Exit 0 written · 2 could not run.
USAGE
}

DIR=""; SPEC=""; TREE=""; LENS=""; OUT="-"
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --spec) [ $# -ge 2 ] || { echo "FAIL  --spec needs a path"; exit 2; }; SPEC="$2"; shift 2 ;;
    --tree) [ $# -ge 2 ] || { echo "FAIL  --tree needs a path"; exit 2; }; TREE="$2"; shift 2 ;;
    --lens) [ $# -ge 2 ] || { echo "FAIL  --lens needs a name"; exit 2; }; LENS="$2"; shift 2 ;;
    --out)  [ $# -ge 2 ] || { echo "FAIL  --out needs a path"; exit 2; };  OUT="$2";  shift 2 ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *) [ -z "$DIR" ] || { echo "FAIL  unexpected extra argument: $1"; exit 2; }; DIR="$1"; shift ;;
  esac
done

[ -z "$DIR" ] && { usage; exit 2; }
[ -f "$DIR/plan.md" ] || { echo "FAIL  no plan.md in $DIR"; exit 2; }
[ -z "$SPEC" ] && { echo "FAIL  --spec is required — the packet is mostly the spec it is judged against"; exit 2; }
[ -f "$SPEC" ] || { echo "FAIL  spec not found: $SPEC"; exit 2; }
[ -z "$TREE" ] && { echo "FAIL  --tree is required — the principles the plan is held to live there"; exit 2; }
[ -f "$TREE" ] || { echo "FAIL  design record not found: $TREE"; exit 2; }
case "$LENS" in
  ""|coverage|sequencing|honesty) ;;
  *) echo "FAIL  unknown lens: $LENS"; echo "      one of: coverage, sequencing, honesty"; exit 2 ;;
esac
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUBRIC="$HERE/../skills/feature-spec/references/plan-rubric.md"
[ -f "$RUBRIC" ] || { echo "FAIL  plan rubric not found: $RUBRIC"; exit 2; }

PYTHONPATH="$HERE/lib" python3 - "$DIR" "$SPEC" "$TREE" "$RUBRIC" "$LENS" "$OUT" <<'PY'
import os, re, sys
from record import Record, Spec, Plan, load_tasks, _bullets, _placeholder

plandir, specpath, treepath = sys.argv[1], sys.argv[2], sys.argv[3]
rubric = open(sys.argv[4]).read()
lens, out = sys.argv[5], sys.argv[6]

plan = Plan.load(os.path.join(plandir, 'plan.md'))
spec = Spec.load(specpath)
rec = Record.load(treepath)
tasks = load_tasks(os.path.join(plandir, 'tasks'))

PREFIX = {'coverage': ('BC', 'AC'), 'sequencing': ('BQ', 'AQ'), 'honesty': ('BH', 'AH')}
LENS_HEADING = {'coverage': 'Lens 1 — Coverage', 'sequencing': 'Lens 2 — Sequencing',
                'honesty': 'Lens 3 — Honesty'}

L = []

def part(title, body, empty_note):
    """One packet section. An empty section says so rather than arriving blank —
    a lens cannot tell nothing-to-say from an extraction that dropped it, and it
    reports the second as a blind spot.

    The template writes an empty section as an italic placeholder rather than
    deleting it, so a section holding only that placeholder is empty too. Passing
    `_none_` through would hand the lens the one word and none of the reason it
    matters — which is the same blind spot by a shorter route."""
    L.append(f"## {title}")
    L.append("")
    text = (body or "").strip("\n")
    real = [l for l in text.splitlines() if l.strip() and not _placeholder(l)]
    L.append(text if real else f"_{empty_note}_")
    L.append("")

L.append("# Plan critic packet")
L.append("")
L.append(f"Plan: `{plandir}/plan.md`  ·  Spec: `{specpath}`  ·  Record: `{treepath}`")
L.append("")
L.append("This is the whole of what you are judging. The prose of the plan and the")
L.append("prose of the spec are deliberately absent — judging a plan needs the tasks,")
L.append("what they claim, and what the spec asked for, not the narrative around them.")
L.append("")
L.append("**The spec has already been through its own critic and is settled.** Judge")
L.append("the plan's reading of it. A finding about the spec itself is out of scope")
L.append("unless the plan misread it.")
L.append("")

# ---- what the spec asked for --------------------------------------------
rows = []
for ident, text, _tag, _n in spec.items():
    rows.append(f"{ident}  {text.strip()}")
part("What the spec asked for", "\n".join(rows), "the spec defines no identifiers")

part("The spec's stories and their priorities",
     "\n".join(f"{p} · {t}" for p, t in spec.stories()),
     "the spec states no prioritised stories — say so if a milestone assumes one")
L.append("**P1 alone is a shippable slice** — that is a guarantee the interview bought,")
L.append("and the first milestone either keeps it or throws it away.")
L.append("")

part("The spec's acceptance scenarios", spec.scenarios_body(),
     "the spec states no acceptance scenarios")

# ---- the plan ------------------------------------------------------------
part("Approach and ordering", plan.section('Approach'),
     "the plan states no approach")

part("Milestones",
     "\n".join(f"- {mid} — {title}: {', '.join(ts) or 'no tasks'}"
               for mid, title, ts in plan.milestones()),
     "the plan declares no milestones")

blocks = []
for tid, t in tasks:
    b = [f"### {tid} — {t.title()}",
         f"Covers: {', '.join(t.covers()) or '—'}   "
         f"Depends on: {', '.join(t.depends()) or '—'}   "
         f"Milestone: {t.field('Milestone') or '—'}   Status: {t.status()}"]
    if t.field('Blocked by'):
        b.append(f"Blocked by: {t.field('Blocked by')}")
    if t.touches():
        b.append(f"Touches: {', '.join(t.touches())}")
    b.append("")
    b.append(f"Goal: {' '.join((t.section('Goal') or '').split()) or '_none stated_'}")
    b.append(f"Why now: {' '.join((t.section('Why now') or '').split()) or '_none stated_'}")
    b.append("")
    b.append("Action items:")
    items = t.action_items()
    b.extend(f"  - {a}" for a in items) if items else b.append("  _none_")
    b.append("")
    b.append("Done when:")
    dw = t.done_when()
    b.extend(f"  - {i}  {x}" for i, x in dw) if dw else b.append("  _none quoted_")
    blocks.append("\n".join(b))
part("The tasks", "\n\n".join(blocks), "the plan has no task files")

part("Not planned",
     "\n".join(f"- {i} — {r or 'NO REASON GIVEN'}" for i, r in plan.not_planned()),
     "the plan leaves nothing out — every identifier is covered by a task")

# These three sections carry an explanatory line above their bullets, so the raw
# body is never blank even when the section says nothing. Passing the parsed
# content is what lets an empty one be recognised as empty.
part("Enabling work — tasks no requirement asked for",
     "\n".join(f"- {b}" for b in _bullets(plan.section('Enabling work'))),
     "the plan declares no enabling work")

part("Plan assumptions — decisions the spec did not settle",
     "\n".join(f"- {text}" for text, _cost in plan.assumptions()),
     "the plan declares no assumptions. The spec names no type, library or "
     "function by design, so an empty section on a non-trivial feature means "
     "the assumptions are invisible rather than absent — check the action items")

part("Open questions the spec carries",
     "\n".join(f"- [NEEDS CLARIFICATION: {m.strip()}]" for m in spec.open_markers()),
     "the spec carries no open questions")
L.append("An open marker is a recorded decision not to decide. A task may be blocked")
L.append("by one; no action item may quietly answer one.")
L.append("")

part("Seams the plan names",
     "\n".join(f"- {path}" + (f"   {tag}" if tag else "") for path, tag in plan.seams()),
     "the plan names no seams — every path in it was checked and resolves")

# ---- what the plan is held to -------------------------------------------
part("The chosen approach, from the design record",
     "\n".join(f"- Chosen{f' ({a})' if a else ''}: {t}" for a, t in rec.strategy()['chosen_axes']),
     "the strategy phase was skipped — say so if the plan's ordering assumes one")

part("Principles in force — the project's own words",
     rec.section('Principles in force'),
     "the repo states no principles; the rule-compliance half of Lens 3 cannot "
     "run — say so in your blind spot")
L.append("**Enforce these words, never your own taste.** A rule the project did not")
L.append("state is not a finding, however sound (R13).")
L.append("")

part("Promoted ADRs the plan must not contradict", rec.section('Promoted to ADR'),
     "no decision was promoted for this feature")

# ---- the rubric, inline --------------------------------------------------
L.append("---")
L.append("")
if lens:
    heading = LENS_HEADING[lens]
    body = re.search(rf'^## {re.escape(heading)}\s*$(.*?)(?=^## |\Z)', rubric, re.M | re.S)
    shared = []
    for name in ('Blocking versus advisory', 'Discipline', 'The anti-rubber-stamp rule',
                 'Output', 'Confidence, calibrated'):
        m = re.search(rf'^## {re.escape(name)}\s*$(.*?)(?=^## |\Z)', rubric, re.M | re.S)
        if m:
            shared.append(f"## {name}\n{m.group(1).rstrip()}\n")
    b, a = PREFIX[lens]
    L.append(f"# Your rubric — {heading.split('—', 1)[-1].strip()}")
    L.append("")
    L.append("You are one of three lenses running in parallel. Judge only your own")
    L.append("lens; the others are covered and duplicating them wastes the pass.")
    L.append("")
    L.append(f"**Number your findings `{b}1`, `{b}2`… under BLOCKING and `{a}1`, `{a}2`… "
             f"under ADVISORY.** Three lenses sharing one numbering cannot be "
             f"reconciled per finding in the second pass.")
    L.append("")
    L.append(f"## {heading}\n{body.group(1).rstrip() if body else ''}")
    L.append("")
    L.extend(shared)
else:
    L.append(re.sub(r'^# Plan critic rubric\s*$', '# Your rubric', rubric.rstrip(),
                    count=1, flags=re.M))

body = "\n".join(L).rstrip() + "\n"
if out == '-':
    sys.stdout.write(body)
else:
    with open(out, 'w') as fh:
        fh.write(body)
    print(f"wrote {out}")
    print(f"  {len(tasks)} task(s) · {len(spec.items())} spec identifiers · "
          f"{len(plan.milestones())} milestone(s)" + (f" · lens: {lens}" if lens else " · all three lenses"))
PY
