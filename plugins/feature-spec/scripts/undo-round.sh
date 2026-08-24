#!/usr/bin/env bash
# ABOUTME: Retracts the last round of a design record — strikes its answers through, returns their
# ABOUTME: questions to the frontier, and rewinds the counters. Makes the interview safe to answer quickly.
#
# A bounded interview is buying speed of answering, and speed of answering needs a
# way back. The record is append-only by construction (R1, Edit not Write), so the
# previous state is reconstructible.
#
# Retracted answers are struck through, never deleted — rule 5 of the record
# format. A record that quietly loses an answer is worse than one that shows the
# user changed their mind.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: undo-round.sh <tree.md> [--round N] [--dry-run]

  --round N   Retract round N. Default: the highest round with settled answers.
  --dry-run   Print what would change and write nothing.

Coverage is NOT rewritten. The previous table is not stored anywhere, and
inventing one would be exactly the fabrication this plugin exists to prevent —
so the record is left marked for a re-score instead.
USAGE
}

TREE=""; ROUND=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --round) [ $# -ge 2 ] || { echo "FAIL  --round needs a number"; exit 2; }; ROUND="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *) [ -z "$TREE" ] || { echo "FAIL  unexpected extra argument: $1"; exit 2; }; TREE="$1"; shift ;;
  esac
done

[ -z "$TREE" ] && { usage; exit 2; }
[ -f "$TREE" ] || { echo "FAIL  no such file: $TREE"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHONPATH="$HERE/lib" python3 - "$TREE" "${ROUND:-}" "$DRY" <<'PY'
import re, sys
from record import Record

path, want, dry = sys.argv[1], sys.argv[2], sys.argv[3] == '1'
rec = Record.load(path)
text = rec.text

settled = rec.settled()
rounds = [e['round'] for e in settled if e['round'] is not None]
if not rounds:
    print("FAIL  no settled answer carries a round tag — nothing to undo", file=sys.stderr)
    sys.exit(2)

target = int(want) if want else max(rounds)
victims = [e for e in settled if e['round'] == target]
if not victims:
    print(f"FAIL  no settled answer is tagged (r{target})", file=sys.stderr)
    print(f"      rounds present: {', '.join(f'r{r}' for r in sorted(set(rounds)))}", file=sys.stderr)
    sys.exit(2)

print(f"Retracting round {target} — {len(victims)} answer(s):")
for e in victims:
    print(f"  {e['id']} {e['title']} → {e['answer'][:60]}")
print()

# --- strike the entries through, in place, and mark them retracted -----------
def strike_block(m):
    """One ## Settled entry: its bullet plus any indented continuation."""
    block = m.group(0)
    qid = re.match(r'^\s*-\s+\*\*(Q\d+)', block).group(1)
    if qid not in {e['id'] for e in victims}:
        return block
    out = []
    for line in block.rstrip('\n').splitlines():
        s = line.strip()
        if not s:
            out.append(line); continue
        indent = line[:len(line) - len(line.lstrip())]
        if s.startswith('-'):
            body = s[1:].strip()
            out.append(f"{indent}- ~~{body}~~  *(retracted, r{target})*")
        else:
            out.append(f"{indent}~~{s}~~")
    return "\n".join(out) + "\n"

sec = re.search(r'(^## Settled[^\n]*\n)(.*?)(?=^## |\Z)', text, re.M | re.S)
if not sec:
    print("FAIL  no ## Settled section", file=sys.stderr); sys.exit(2)
body = re.sub(r'^\s*-\s+\*\*Q\d+.*?(?=^\s*-\s+\*\*Q\d+|\Z)', strike_block,
              sec.group(2), flags=re.M | re.S)
text = text[:sec.start(2)] + body + text[sec.end(2):]

# --- return the questions to the frontier ------------------------------------
already = set(re.findall(r'\*\*(Q\d+)', Record(text).section('Frontier') or ''))
returning = [e for e in victims if e['id'] not in already]
if returning:
    fm = re.search(r'(^## Frontier[^\n]*\n)(.*?)(?=^## |\Z)', text, re.M | re.S)
    if fm:
        lines = [f"- **{e['id']} {e['title']}** — deps: none — returned from r{target}"
                 for e in returning]
        block = fm.group(2).rstrip('\n')
        block = (block + "\n" if block.strip() else "") + "\n".join(lines) + "\n\n"
        text = text[:fm.start(2)] + block + text[fm.end(2):]
        print(f"Returned to ## Frontier: {', '.join(e['id'] for e in returning)}")

# --- rewind the protocol -----------------------------------------------------
proto = rec.protocol()
new_round = max(1, target - 1)
new_q = max(0, (proto['questions'] or 0) - len(victims))
pm = re.search(r'(^## Protocol[^\n]*\n)(.*?)(?=^## |\Z)', text, re.M | re.S)
if pm:
    blk = pm.group(2)
    blk = re.sub(r'Round:\s*\d+', f'Round: {new_round}', blk, count=1)
    blk = re.sub(r'questions\s+\d+', f'questions {new_q}', blk, count=1)
    blk = re.sub(r'Guard:[^\n]*', 'Guard: not tripped', blk, count=1)
    text = text[:pm.start(2)] + blk + text[pm.end(2):]
    print(f"Protocol: round {proto['round']} → {new_round}, "
          f"questions {proto['questions']} → {new_q}, guard reset")

# --- coverage is marked, never invented --------------------------------------
cm = re.search(r'(^## Coverage[^\n]*\n)', text, re.M)
NOTE = ("\n> **Re-score required.** Round %d was retracted; the table below still\n"
        "> reflects it. The previous table is not stored, and inventing one would be\n"
        "> the fabrication this record exists to prevent.\n\n") % target
if cm and 'Re-score required' not in text:
    text = text[:cm.end(1)] + NOTE + text[cm.end(1):]
    print("Coverage: marked for re-score (not rewritten)")

if dry:
    print()
    print("--dry-run: nothing written.")
    sys.exit(0)

with open(path, 'w') as fh:
    fh.write(text)
print()
print(f"Rewrote {path}.")
print("Re-score the coverage table, then re-run check-tree.sh.")
PY
