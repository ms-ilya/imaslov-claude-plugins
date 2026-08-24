#!/usr/bin/env bash
# ABOUTME: Assembles the Phase 6 critic packet from the spec and the design record — the nine parts
# ABOUTME: drafting.md names, plus the rubric inline, so no lens is blinded by a hand-rolled extraction.
#
# drafting.md described the packet in prose and left every run to build it with
# sed. A range that captured `## Out of scope` without its content produced a
# lens that declared a blind spot it could not have had: scope-boundary
# compliance was unassessable because the section arrived empty. Phase 6 is the
# phase most sensitive to input shape and was the only one assembling its input
# by hand.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: make-packet.sh <spec.md> --tree <tree.md> [--lens <name>] [--out <path>]

  Prints the critic packet on stdout, ready to paste into the spec-critic
  dispatch. NOT the whole draft: prose sections double the phase's cost, and a
  lens that seems to need one is a sign the packet is wrong.

  --lens <name>  completeness | consistency | principles
                 Emits only that lens's rubric section and assigns the lens its
                 own finding-id prefix. Use in --deep, where three agents run in
                 parallel and would otherwise all number their findings B1.
                 Omit for the single-agent default: all three lenses, plain
                 B<n>/A<n>.
  --out <path>   Write to a file instead of stdout. Pass - for stdout.

Exit 0 written · 2 could not run.
USAGE
}

SPEC=""; TREE=""; LENS=""; OUT="-"
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --tree) [ $# -ge 2 ] || { echo "FAIL  --tree needs a path"; exit 2; }; TREE="$2"; shift 2 ;;
    --lens) [ $# -ge 2 ] || { echo "FAIL  --lens needs a name"; exit 2; }; LENS="$2"; shift 2 ;;
    --out)  [ $# -ge 2 ] || { echo "FAIL  --out needs a path"; exit 2; };  OUT="$2";  shift 2 ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *) [ -z "$SPEC" ] || { echo "FAIL  unexpected extra argument: $1"; exit 2; }; SPEC="$1"; shift ;;
  esac
done

[ -z "$SPEC" ] && { usage; exit 2; }
[ -f "$SPEC" ] || { echo "FAIL  no such file: $SPEC"; exit 2; }
[ -z "$TREE" ] && { echo "FAIL  --tree is required — the packet is mostly the record"; exit 2; }
[ -f "$TREE" ] || { echo "FAIL  design record not found: $TREE"; exit 2; }
case "$LENS" in
  ""|completeness|consistency|principles) ;;
  *) echo "FAIL  unknown lens: $LENS"; echo "      one of: completeness, consistency, principles"; exit 2 ;;
esac
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUBRIC="$HERE/../skills/feature-spec/references/critic-rubric.md"
[ -f "$RUBRIC" ] || { echo "FAIL  critic rubric not found: $RUBRIC"; exit 2; }

PYTHONPATH="$HERE/lib" python3 - "$SPEC" "$TREE" "$RUBRIC" "$LENS" "$OUT" <<'PY'
import os
import re
import sys
from record import Record, Spec, tag_sources

spec = Spec.load(sys.argv[1])
rec = Record.load(sys.argv[2])
rubric = open(sys.argv[3]).read()
lens = sys.argv[4]
out = sys.argv[5]

# Each parallel lens numbers its findings in its own space. Three agents all
# emitting B1 is not a naming quibble: the second pass reconciles per id, and
# two findings sharing one id cannot both be reported.
PREFIX = {'completeness': ('BC', 'AC'), 'consistency': ('BS', 'AS'),
          'principles': ('BP', 'AP')}
LENS_HEADING = {'completeness': 'Lens 1 — Completeness',
                'consistency': 'Lens 2 — Consistency',
                'principles': 'Lens 3 — Principles'}

L = []


def part(title, body, empty_note):
    """One packet section. An empty section says so rather than arriving blank.

    A lens cannot tell a section with nothing in it from a section the
    extraction dropped, and it reports the second as a blind spot."""
    L.append(f"## {title}")
    L.append("")
    text = (body or "").strip("\n")
    L.append(text if text.strip() else f"_{empty_note}_")
    L.append("")


def spec_section(*names):
    for h, a, b in spec.sections:
        if h in names:
            return "\n".join(spec.lines[a:b + 1])
    return None


# ---- header --------------------------------------------------------------
L.append("# Critic packet")
L.append("")
L.append(f"Spec: `{sys.argv[1]}`  ·  Record: `{sys.argv[2]}`")
L.append("")
L.append("This is the whole of what you are judging. It is not an excerpt of a")
L.append("longer document you should ask for — the prose sections of the spec are")
L.append("deliberately absent, because judging the writing needs the statements and")
L.append("their provenance, not the narrative around them.")
L.append("")

# ---- 1 & 2: the statements, with their tags ------------------------------
items = spec.items()
rows = []
for ident, text, tagline, lineno in items:
    srcs = tag_sources(tagline)
    rows.append(f"{ident}  {text.strip()}")
    rows.append(f"        ← {', '.join(srcs) if srcs else 'UNTAGGED'}")
part("Requirements and success criteria, with source tags", "\n".join(rows),
     "the spec defines no FR or SC identifiers")

part("Acceptance scenarios", spec.scenarios_body(),
     "no ## Acceptance scenarios section in the spec")

# ---- 3: coverage, Clear* intact ------------------------------------------
cov = rec.coverage()
part("Coverage at the end of the interview",
     "\n".join(["| Category | Status |", "|---|---|"]
               + [f"| {c} | {st} |" for c, st in cov]),
     "the record has no coverage table")

# ---- 4: deferred ---------------------------------------------------------
deferred = rec.deferred_entries()
part("Deliberately deferred — these ship as [NEEDS CLARIFICATION]",
     "\n".join(f"- **{d['id']} {d['title']}** — {d['reason']}" for d in deferred),
     "nothing was deferred")
L.append("A deferred item is a recorded decision, not an omission. Flagging one as")
L.append("incomplete is a misread of this packet, not a finding.")
L.append("")

# ---- 5: strategy ---------------------------------------------------------
strat = rec.strategy()
lines = []
for axis, text in strat['chosen_axes']:
    lines.append(f"- Chosen{f' ({axis})' if axis else ''}: {text}")
for axis, text in strat['rejected_axes']:
    lines.append(f"- Rejected{f' ({axis})' if axis else ''}: {text}")
part("Chosen and rejected strategy", "\n".join(lines),
     "the strategy phase was skipped — say so if a requirement assumes one")

# ---- 6: promoted ADRs, with their decisions ------------------------------
adr_lines = []
for line in (rec.section('Promoted to ADR') or '').splitlines():
    if not line.strip().startswith('-'):
        continue
    adr_lines.append(line.strip())
    # The title alone does not say what was decided, and "contradicts a
    # promoted ADR" is blocking — so the decision has to be in the packet.
    m = re.search(r'(ADR-[\w.-]+)', line)
    for path in rec.reads():
        base = os.path.basename(path)
        if not base.endswith('.md'):
            continue
        if m and m.group(1).lower().replace('adr-', '') not in base.lower():
            continue
        full = os.path.expanduser(path)
        if not os.path.isfile(full):
            for root in (os.path.dirname(sys.argv[2]), '.'):
                cand = os.path.join(root, path)
                if os.path.isfile(cand):
                    full = cand
                    break
        if not os.path.isfile(full):
            continue
        d = re.search(r'^## Decision\s*$(.*?)(?=^## |\Z)', open(full).read(), re.M | re.S)
        if d and d.group(1).strip():
            adr_lines.append(f"  Decision: {d.group(1).strip().splitlines()[0]}")
        break
part("Promoted ADRs", "\n".join(adr_lines), "no decision was promoted this run")

# ---- 7: the project's own rules, verbatim --------------------------------
part("Principles in force — the project's own words",
     rec.section('Principles in force'),
     "the repo states no principles; Lens 3 cannot run — say so in your blind spot")
L.append("**Enforce these words, never your own taste.** A rule the project did not")
L.append("state is not a finding, however sound (R13).")
L.append("")

# ---- 8: the scope boundary -----------------------------------------------
# The section a hand-rolled sed range captured as a heading with no body, which
# is what blinded a lens: it could not check scope compliance against a
# boundary that never arrived.
part("Out of scope", spec_section('out of scope', 'non goals', 'nongoals'),
     "the spec states no scope boundary — that absence is itself checkable")

part("Open questions carried into the spec",
     "\n".join(f"- [NEEDS CLARIFICATION: {m.strip()}]" for m in spec.open_markers()),
     "no open markers")

# ---- 9: the rubric, inline ----------------------------------------------
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
    L.append(f"# Your rubric — {heading.split('—', 1)[-1].strip()}")
    L.append("")
    L.append("You are one of three lenses running in parallel. Judge only your own")
    L.append("lens; the others are covered and duplicating them wastes the pass.")
    L.append("")
    b, a = PREFIX[lens]
    L.append(f"**Number your findings `{b}1`, `{b}2`… under BLOCKING and `{a}1`, `{a}2`… "
             f"under ADVISORY.** Three lenses sharing one numbering cannot be "
             f"reconciled per finding in the second pass.")
    L.append("")
    L.append(f"## {heading}\n{body.group(1).rstrip() if body else ''}")
    L.append("")
    L.extend(shared)
else:
    L.append(re.sub(r'^# Critic rubric\s*$', '# Your rubric', rubric.rstrip(), count=1, flags=re.M))

body = "\n".join(L).rstrip() + "\n"
if out == '-':
    sys.stdout.write(body)
else:
    with open(out, 'w') as fh:
        fh.write(body)
    print(f"wrote {out}")
    print(f"  {len(items)} statements · {len(cov)} coverage rows · {len(deferred)} deferred"
          + (f" · lens: {lens}" if lens else " · all three lenses"))
PY
