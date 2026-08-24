#!/usr/bin/env bash
# ABOUTME: Renders what an amendment actually changed — requirements added, withdrawn, reworded under a
# ABOUTME: stable identifier, and criteria whose numbers moved. What a reviewer of an amended spec needs.
#
# The critic never sees the previous version, so critique.md structurally cannot
# show this. Amendment is also the path where identifier stability matters most,
# which makes it the path most worth rendering rather than describing.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: spec-diff.sh <old-spec.md> <new-spec.md> [--out <path>] [--tree <tree.md>]

  --out <path>   Where to write. Default: stdout. A path writes a markdown report.
  --tree <path>  Resolve each changed requirement's source tag, so the report can
                 say which answer moved as well as which requirement did.

Exit 0 when nothing structurally alarming changed, 1 when an identifier vanished
or changed meaning without being marked withdrawn.
USAGE
}

OLD=""; NEW=""; OUT="-"; TREE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --out)  [ $# -ge 2 ] || { echo "FAIL  --out needs a path"; exit 2; };  OUT="$2";  shift 2 ;;
    --tree) [ $# -ge 2 ] || { echo "FAIL  --tree needs a path"; exit 2; }; TREE="$2"; shift 2 ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *) if   [ -z "$OLD" ]; then OLD="$1"
       elif [ -z "$NEW" ]; then NEW="$1"
       else echo "FAIL  unexpected extra argument: $1"; exit 2; fi; shift ;;
  esac
done

[ -z "$OLD" ] || [ -z "$NEW" ] && { usage; exit 2; }
[ -f "$OLD" ] || { echo "FAIL  no such file: $OLD"; exit 2; }
[ -f "$NEW" ] || { echo "FAIL  no such file: $NEW"; exit 2; }
[ -n "$TREE" ] && [ ! -f "$TREE" ] && { echo "FAIL  design record not found: $TREE"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHONPATH="$HERE/lib" python3 - "$OLD" "$NEW" "$OUT" "$TREE" <<'PY'
import difflib, os, sys
from record import Record, Spec, tag_sources

old = Spec.load(sys.argv[1])
new = Spec.load(sys.argv[2])
out = sys.argv[3]
rec = Record.load(sys.argv[4]) if sys.argv[4] and os.path.isfile(sys.argv[4]) else None

def index(spec):
    return {i: {'text': t.strip(), 'tag': ', '.join(tag_sources(tag)) or None, 'line': n}
            for i, t, tag, n in spec.items()}

O, N = index(old), index(new)

added     = [i for i in N if i not in O]
gone      = [i for i in O if i not in N]
withdrawn = [i for i in gone if 'withdrawn' in O[i]['text'].lower()]
withdrawn += [i for i in N if i in O and 'withdrawn' in N[i]['text'].lower()
              and 'withdrawn' not in O[i]['text'].lower()]
vanished  = [i for i in gone if i not in withdrawn]
reworded  = [i for i in N if i in O and N[i]['text'] != O[i]['text']
             and 'withdrawn' not in N[i]['text'].lower()]
retagged  = [i for i in N if i in O and N[i]['tag'] != O[i]['tag']]
unchanged = [i for i in N if i in O and N[i]['text'] == O[i]['text']]

def wordlevel(a, b):
    """The changed words only — a reviewer wants the delta, not two paragraphs."""
    sm = difflib.SequenceMatcher(None, a.split(), b.split())
    parts = []
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op == 'equal':
            seg = a.split()[i1:i2]
            parts.append(' '.join(seg if len(seg) <= 6 else seg[:3] + ['…'] + seg[-3:]))
        elif op == 'delete':
            parts.append('~~' + ' '.join(a.split()[i1:i2]) + '~~')
        elif op == 'insert':
            parts.append('**' + ' '.join(b.split()[j1:j2]) + '**')
        else:
            parts.append('~~' + ' '.join(a.split()[i1:i2]) + '~~ **'
                         + ' '.join(b.split()[j1:j2]) + '**')
    return ' '.join(p for p in parts if p)

L = []
L.append("# Amendment diff")
L.append("")
L.append(f"`{os.path.basename(sys.argv[1])}` → `{os.path.basename(sys.argv[2])}`")
L.append("")
L.append(f"{len(unchanged)} unchanged · {len(added)} added · {len(reworded)} reworded · "
         f"{len(withdrawn)} withdrawn · {len(vanished)} vanished")
L.append("")

if vanished:
    L.append("## Vanished — this is the damage the check exists to catch")
    L.append("")
    L.append("An identifier that disappears rather than being marked `(withdrawn)` takes")
    L.append("its history with it. Anything that cited it now cites nothing.")
    L.append("")
    for i in sorted(vanished):
        L.append(f"- **`{i}`** was: {O[i]['text'][:110]}")
    L.append("")

if reworded:
    L.append("## Reworded under a stable identifier")
    L.append("")
    L.append("The number stayed; the meaning may not have. This is the section to read")
    L.append("closely — to anyone who was not present, a reword and a renumber look the same.")
    L.append("")
    for i in sorted(reworded):
        L.append(f"- **`{i}`** {wordlevel(O[i]['text'], N[i]['text'])}")
        if rec and N[i]['tag'] and N[i]['tag'] != O[i]['tag']:
            L.append(f"  - source moved: `{O[i]['tag']}` → `{N[i]['tag']}`")
    L.append("")

if added:
    L.append("## Added")
    L.append("")
    for i in sorted(added):
        tag = f"  ← `{N[i]['tag']}`" if N[i]['tag'] else "  ← **no source tag**"
        L.append(f"- **`{i}`** {N[i]['text'][:110]}")
        L.append(f"{tag}")
    L.append("")

if withdrawn:
    L.append("## Withdrawn, correctly")
    L.append("")
    L.append("Marked in place rather than deleted, so every prior citation still resolves.")
    L.append("")
    for i in sorted(set(withdrawn)):
        src = N.get(i) or O.get(i)
        L.append(f"- **`{i}`** {src['text'][:110]}")
    L.append("")

retag_only = [i for i in retagged if i not in reworded]
if retag_only:
    L.append("## Same text, different source")
    L.append("")
    L.append("The requirement did not change but its provenance did — worth confirming the")
    L.append("new answer really says the same thing as the old one.")
    L.append("")
    for i in sorted(retag_only):
        L.append(f"- **`{i}`** `{O[i]['tag']}` → `{N[i]['tag']}`")
    L.append("")

old_scen, new_scen = old.scenarios_body(), new.scenarios_body()
lost = [i for i in N if i.startswith('FR') and i in old_scen and i not in new_scen]
if lost:
    L.append("## Lost their acceptance scenario")
    L.append("")
    for i in sorted(lost):
        L.append(f"- **`{i}`** had a scenario in the previous spec and has none now")
    L.append("")

if not (vanished or reworded or added or withdrawn or retag_only or lost):
    L.append("Nothing changed between these two specs.")
    L.append("")

body = "\n".join(L)
if out == '-':
    print(body)
else:
    with open(out, 'w') as fh:
        fh.write(body + "\n")
    print(f"wrote {out}")
    print(f"  {len(unchanged)} unchanged · {len(added)} added · {len(reworded)} reworded · "
          f"{len(withdrawn)} withdrawn · {len(vanished)} vanished")

sys.exit(1 if vanished or lost else 0)
PY
