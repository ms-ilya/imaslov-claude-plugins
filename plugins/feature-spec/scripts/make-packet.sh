#!/usr/bin/env bash
# ABOUTME: Assembles the Phase 6 critic packet from the spec and the design record — every part a lens
# ABOUTME: judges, plus the rubric, so no check is asked of the critic without the text it needs.
#
# The critic sees nothing but this packet. A part left out is a check it cannot
# run, and a critic asked to run a check it has no input for either declares a
# blind spot or reports the check as passed.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: make-packet.sh <spec.md> --tree <tree.md> [--out <path>] [--pass1 <path>]

  Builds the critic packet: the spec's statements with what they cite, and the
  parts of the record a lens judges them against.

  --out <path>    Write to a file instead of stdout, so the critic can be handed
                  a path and the packet is never retyped. Pass - for stdout.
                  The convention is <specdir>/.work/critic-packet.md: a `.work`
                  directory is created with an ignore file of its own, so the
                  packet never reaches version control.
  --pass1 <path>  The first pass's saved reply. Its blocking findings are added
                  to the packet, so a second pass can say what became of each.

Exit 0 written · 2 could not run.
USAGE
}

SPEC=""; TREE=""; OUT="-"; PASS1=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --tree) [ $# -ge 2 ] || { echo "FAIL  --tree needs a path"; exit 2; }; TREE="$2"; shift 2 ;;
    --out)  [ $# -ge 2 ] || { echo "FAIL  --out needs a path"; exit 2; };  OUT="$2";  shift 2 ;;
    --pass1) [ $# -ge 2 ] || { echo "FAIL  --pass1 needs a path"; exit 2; }; PASS1="$2"; shift 2 ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *) [ -z "$SPEC" ] || { echo "FAIL  unexpected extra argument: $1"; exit 2; }; SPEC="$1"; shift ;;
  esac
done

[ -z "$SPEC" ] && { usage; exit 2; }
[ -f "$SPEC" ] || { echo "FAIL  no such file: $SPEC"; exit 2; }
[ -z "$TREE" ] && { echo "FAIL  --tree is required — the packet is mostly the record"; exit 2; }
[ -f "$TREE" ] || { echo "FAIL  design record not found: $TREE"; exit 2; }
if [ -n "$PASS1" ] && [ ! -f "$PASS1" ]; then
  echo "FAIL  first pass not found: $PASS1"
  exit 2
fi
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUBRIC="$HERE/../skills/feature-spec/references/critic-rubric.md"
[ -f "$RUBRIC" ] || { echo "FAIL  critic rubric not found: $RUBRIC"; exit 2; }

PYTHONPATH="$HERE/lib" python3 - "$SPEC" "$TREE" "$RUBRIC" "$OUT" "$PASS1" <<'PY'
import os
import re
import sys
from record import Record, Spec, tag_sources, search_roots, resolve_path

spec = Spec.load(sys.argv[1])
rec = Record.load(sys.argv[2])
rubric = open(sys.argv[3]).read()
out = sys.argv[4]
pass1 = open(sys.argv[5]).read() if sys.argv[5] else None
# Paths in the record are written from the repository root, which is some
# ancestor of the record itself. The process cwd says nothing about either.
roots = search_roots(os.path.dirname(os.path.abspath(sys.argv[2])))

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


# ---- header --------------------------------------------------------------
L.append("# Critic packet")
L.append("")
L.append(f"Spec: `{sys.argv[1]}`  ·  Record: `{sys.argv[2]}`")
L.append("")
L.append("This is the whole of what you are judging: every statement the spec makes,")
L.append("what each one cites, and the parts of the record the rubric measures them")
L.append("against. Only the spec's clarifications index is left out; it repeats the")
L.append("decisions already printed below.")
L.append("")

# ---- the framing: the one place a claim can sit with no tag on it --------
part("Opening paragraph", spec.intro(), "the spec has no opening paragraph")
part("User stories", spec.section_text('user stories'),
     "the spec has no ## User stories section, so no priority was drafted")

# ---- 1 & 2: the statements, with their tags ------------------------------
items = spec.items()
rows = []
for ident, text, tagline, lineno in items:
    srcs = tag_sources(tagline)
    rows.append(f"{ident}  {text.strip()}")
    rows.append(f"        ← {', '.join(srcs) if srcs else 'UNTAGGED'}")
part("Requirements and success criteria, with source tags", "\n".join(rows),
     "the spec defines no FR or SC identifiers")

# ---- what the tags cite, in full ------------------------------------------
# A tag says where a statement came from. Whether the statement says what its
# source says can only be judged with the source's text in hand, and the critic
# cannot open the record.
settled = {e['id']: e for e in rec.settled()}
facts = rec.grounding_facts()
cited = []
for _lineno, line in spec.all_tags():
    for src in tag_sources(line):
        if src not in cited:
            cited.append(src)
src_lines = []
for src in cited:
    if src.startswith('Settled ') and src.split()[-1] in settled:
        e = settled[src.split()[-1]]
        src_lines.append(f"- **{src} {e['title']}** → {e['answer']}")
        if e['why']:
            src_lines.append(f"  Why: {e['why']}")
    elif src.startswith('Grounding fact ') and src.split()[-1] in facts:
        src_lines.append(f"- **{src}** — {facts[src.split()[-1]]}")
part("What those tags cite — the decisions and facts, in the record's words",
     "\n".join(src_lines),
     "no tag cites a settled decision or a grounding fact")

# What no tag cites is still part of the record. Without it the critic raises
# what a fact already answers, and cannot see a decision the spec left out.
rest = [f"- **Settled {e['id']} {e['title']}** → {e['answer']}" for e in rec.settled()
        if f"Settled {e['id']}" not in cited]
rest += [f"- **Grounding fact {n}** — {text}" for n, text in rec.grounding_fact_list()
         if f"Grounding fact {n}" not in cited]
part("Decided or found, and cited by no statement", "\n".join(rest),
     "every decision and grounding fact in the record is cited")

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
# The spec retells the strategy in its own words, and a retelling can drift.
part("The spec's own account of the approach", spec.section_text('chosen approach'),
     "the spec has no ## Chosen approach section")

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
        full = resolve_path(path, roots)
        if not full or not os.path.isfile(full):
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
part("Principle deviations the spec declares", spec.section_text('principle deviations'),
     "the spec declares no deviation from a stated principle")

# ---- 7b: the vocabulary --------------------------------------------------
# Titles alone cannot show a term used against its definition, so each term
# travels with its entry.
terms = [t.strip().strip('*`') for line in (rec.section('Glossary written') or '').splitlines()
         if line.strip().startswith('-') for t in line.strip().lstrip('- ').split(',') if t.strip()]
gloss = next((full for path in rec.reads() if os.path.basename(path).lower() == 'glossary.md'
              for full in [resolve_path(path, roots)] if full and os.path.isfile(full)), None)
gloss_text = open(gloss).read() if gloss else ''
term_lines = []
for t in terms:
    m = re.search(rf'^## {re.escape(t)}[ \t]*$(.*?)(?=^## |\Z)', gloss_text, re.M | re.S | re.I)
    entry = ' '.join(m.group(1).split()) if m else ''
    term_lines.append(f"- **{t}** — {entry}" if entry
                      else f"- **{t}** — _the record lists this term, and the glossary has no entry for it_")
part("Glossary terms this feature defined", "\n".join(term_lines),
     "no term was written to the glossary for this feature")

# ---- 8: the scope boundary -----------------------------------------------
# The section a hand-rolled sed range captured as a heading with no body, which
# is what blinded a lens: it could not check scope compliance against a
# boundary that never arrived.
part("Out of scope", spec.section_text('out of scope', 'non goals', 'nongoals'),
     "the spec states no scope boundary — that absence is itself checkable")

part("Implementation constraints — decisions about how, made by the user",
     spec.section_text('implementation constraints'),
     "the user fixed nothing about how this is built")
L.append("These are the only lines in a spec allowed to name a type, a library or a")
L.append("function. A requirement that does so is still a finding.")
L.append("")

part("Open questions carried into the spec",
     "\n".join(f"- [NEEDS CLARIFICATION: {m.strip()}]" for m in spec.open_markers()),
     "no open markers")

# ---- 8b: what the first pass found ---------------------------------------
# A second pass runs in fresh context. It can only say whether B1 was fixed if
# it is told what B1 was.
if pass1 is not None:
    m = re.search(r'^BLOCKING[ \t]*$(.*?)(?=^(?:[A-Z][A-Z ]*[A-Z]|[A-Z]+)[ \t]*$|\Z)',
                  pass1, re.M | re.S)
    part("Findings from the first pass", (m.group(1) if m else ''),
         "the first pass raised nothing blocking")
    L.append("The draft was revised after these. Add a RECONCILIATION section with one")
    L.append("line for each id above: `- B1 fixed` or `- B2 not fixed — <why>`. A finding")
    L.append("that is not fixed keeps the verdict at fix-first. Number a new blocking")
    L.append("finding after the highest id above.")
    L.append("")

# ---- 9: the rubric, inline ----------------------------------------------
L.append("---")
L.append("")
L.append(re.sub(r'^# Critic rubric\s*$', '# Your rubric', rubric.rstrip(), count=1, flags=re.M))

body = "\n".join(L).rstrip() + "\n"
if out == '-':
    sys.stdout.write(body)
else:
    # A packet is working state: only the critic reads it, and nothing reads it
    # after the run. Written under `.work/`, it is kept out of version control
    # by an ignore file of its own, so nothing has to delete it afterwards.
    parent = os.path.dirname(os.path.abspath(out))
    os.makedirs(parent, exist_ok=True)
    ignore = os.path.join(parent, '.gitignore')
    if os.path.basename(parent) == '.work' and not os.path.exists(ignore):
        with open(ignore, 'w') as fh:
            fh.write("*\n")
    with open(out, 'w') as fh:
        fh.write(body)
    print(f"wrote {out}")
    print(f"  {len(items)} statements · {len(cov)} coverage rows · {len(deferred)} deferred"
          + " · all three lenses")
PY
