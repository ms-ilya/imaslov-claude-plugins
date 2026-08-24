#!/usr/bin/env bash
# ABOUTME: Generates traceability.md — every requirement joined to the question that produced it, with
# ABOUTME: the answer, the reasoning and the round. Derived entirely from existing source tags.
#
# The join costs one script and zero interview tokens, because the spec already
# carries the tags and the record already carries the reasoning. It is what makes
# a spec defensible in review three months later, which is the case this plugin
# is explicitly built for.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: make-traceability.sh <spec.md> --tree <tree.md> [--out <path>]

  --out <path>   Where to write. Defaults to traceability.md beside the spec.
                 Pass - to write to stdout.
USAGE
}

SPEC=""; TREE=""; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --tree) [ $# -ge 2 ] || { echo "FAIL  --tree needs a path"; exit 2; }; TREE="$2"; shift 2 ;;
    --out)  [ $# -ge 2 ] || { echo "FAIL  --out needs a path"; exit 2; };  OUT="$2";  shift 2 ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *) [ -z "$SPEC" ] || { echo "FAIL  unexpected extra argument: $1"; exit 2; }; SPEC="$1"; shift ;;
  esac
done

[ -z "$SPEC" ] && { usage; exit 2; }
[ -f "$SPEC" ] || { echo "FAIL  no such file: $SPEC"; exit 2; }
[ -z "$TREE" ] && { echo "FAIL  --tree is required"; exit 2; }
[ -f "$TREE" ] || { echo "FAIL  design record not found: $TREE"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found"; exit 2; }
[ -n "$OUT" ] || OUT="$(dirname "$SPEC")/traceability.md"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHONPATH="$HERE/lib" python3 - "$SPEC" "$TREE" "$OUT" <<'PY'
import sys
from record import Record, Spec, tag_sources, resolve_tag

spec = Spec.load(sys.argv[1])
rec = Record.load(sys.argv[2])
out = sys.argv[3]

settled = {e['id']: e for e in rec.settled()}
facts = rec.grounding_facts()
strat = rec.strategy()

L = []
L.append("# Traceability")
L.append("")
L.append("Generated from the spec's source tags and the design record. Every row is")
L.append("a requirement joined to the decision that produced it. **Do not edit —**")
L.append("regenerate with `make-traceability.sh`.")
L.append("")
L.append(f"Record: `{sys.argv[2]}`  ·  Spec: `{sys.argv[1]}`")
L.append("")

# A tag may name several sources, and an answer cited in second position is
# still cited. Reading only the first reported a real answer as never used —
# in a section the operator is told to read before reporting.
def describe(src):
    """(origin, answer, reasoning, round) for one resolved source."""
    q = settled.get(src.replace('Settled ', '')) if src.startswith('Settled ') else None
    if q:
        return (f"{q['id']} {q['title']}".strip(), q['answer'], q['why'],
                f"r{q['round']}" if q['round'] is not None else "")
    if src.startswith('Grounding fact '):
        n = src.split()[-1]
        return f"Grounding fact {n}", facts.get(n, ""), "found in the repo, not asked", "r0"
    if src == 'Strategy (chosen)':
        return ("Strategy", strat['chosen'] or "",
                f"rejected: {strat['rejected']}" if strat['rejected'] else "", "")
    return src, "", "external source", ""


rows, unresolved, untagged = [], [], []
settled_used = set()
for ident, text, tagline, lineno in spec.items():
    srcs = tag_sources(tagline)
    if not srcs:
        untagged.append(ident)
        continue
    bad = [(src, why) for src in srcs for why in [resolve_tag(src, rec)] if why]
    if bad:
        unresolved.extend((ident, src, why) for src, why in bad)
        continue
    parts = [describe(src) for src in srcs]
    settled_used |= {src.replace('Settled ', '') for src in srcs if src.startswith('Settled ')}
    rows.append((ident, text.strip(),
                 " · ".join(p[0] for p in parts if p[0]),
                 " · ".join(p[1] for p in parts if p[1]),
                 " · ".join(p[2] for p in parts if p[2]),
                 " · ".join(dict.fromkeys(p[3] for p in parts if p[3]))))

def cell(s, n=None):
    s = (s or "").replace("|", "\\|").replace("\n", " ").strip()
    return s[:n] + "…" if n and len(s) > n else s

L.append("| Requirement | Statement | Came from | The answer given | Reasoning | Round |")
L.append("|---|---|---|---|---|---|")
for ident, text, origin, answer, reasoning, rnd in rows:
    L.append(f"| `{ident}` | {cell(text,90)} | {cell(origin)} | {cell(answer,90)} | "
             f"{cell(reasoning,90)} | {rnd} |")
L.append("")

deferred = rec.deferred_entries()
if deferred:
    L.append("## Deferred, and therefore untraced")
    L.append("")
    L.append("These ship as `[NEEDS CLARIFICATION]` markers. A deliberate gap is a")
    L.append("recorded decision, not an omission — but it is not a decided requirement")
    L.append("either, and this is where that shows.")
    L.append("")
    for d in deferred:
        L.append(f"- **{d['id']} {d['title']}** — {d['reason']}")
    L.append("")

unused = [e for e in rec.settled() if e['id'] not in settled_used]
if unused:
    L.append("## Answered but not traced to any requirement")
    L.append("")
    L.append("An answer the user gave that no requirement cites. Either the spec is")
    L.append("missing something the interview decided, or the question did not earn")
    L.append("its slot. Both are worth a look.")
    L.append("")
    for e in unused:
        L.append(f"- **{e['id']} {e['title']}** → {e['answer']}")
    L.append("")

if untagged or unresolved:
    L.append("## Not traceable")
    L.append("")
    for i in untagged:
        L.append(f"- `{i}` carries no source tag")
    for i, src, why in unresolved:
        L.append(f"- `{i}` cites `{src}` — {why}")
    L.append("")

body = "\n".join(L)
if out == '-':
    print(body)
else:
    with open(out, 'w') as fh:
        fh.write(body + "\n")
    print(f"wrote {out}")
    print(f"  {len(rows)} traced · {len(deferred)} deferred · {len(unused)} answered-but-unused "
          f"· {len(untagged)+len(unresolved)} untraceable")
if untagged or unresolved:
    sys.exit(1)
PY
