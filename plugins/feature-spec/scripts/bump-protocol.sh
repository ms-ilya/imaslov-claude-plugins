#!/usr/bin/env bash
# ABOUTME: Rewrites the ## Protocol block in a design record — increments counters, recomputes the guard,
# ABOUTME: and prints the result. The counters are mechanical data, so a script owns them, not the model.
#
# R7 is one of the two rules the skill names as the ones that slip first, and it
# asks the model to re-transcribe six numbers at the end of every round under
# exactly the context pressure that makes transcription go wrong. Nothing about
# those numbers needs judgement.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: bump-protocol.sh <tree.md> [changes...]

  --round               advance to the next round
  --questions N         add N to the questions counter
  --fact-finders N      add N to the fact-finder dispatch counter
  --references N        add N to the reference-files-loaded counter
  --read N              record ONE Read of N lines — bumps the read count, adds
                        N to lines read, and keeps the largest. Repeatable.
  --critic-pass         add one critic pass
  --next-phase N        set Next phase
  --unlocked yes|no     set "4th round unlocked"
  --set-round N         set the round outright, for --resume
  --show                print the block and change nothing

The guard line is always recomputed from the counters and never taken on trust:
it trips when any two are at or over threshold. Exits 3 when the guard has just
tripped, so a caller can branch on it.

Two thresholds are relative to the mode rather than fixed, because `--deep`
mandates four fact-finders and ten reference files: a fixed threshold below the
mode's own mandate trips before the interview asks anything.
USAGE
}

TREE=""; ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --round|--critic-pass|--show) ARGS+=("$1"); shift ;;
    --questions|--fact-finders|--references|--read|--next-phase|--unlocked|--set-round)
      [ $# -ge 2 ] || { echo "FAIL  $1 needs a value"; exit 2; }
      ARGS+=("$1" "$2"); shift 2 ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *)
      [ -z "$TREE" ] || { echo "FAIL  unexpected extra argument: $1"; exit 2; }
      TREE="$1"; shift ;;
  esac
done

[ -z "$TREE" ] && { usage; exit 2; }
[ -f "$TREE" ] || { echo "FAIL  no such file: $TREE"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found — bump-protocol.sh cannot run"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHONPATH="$HERE/lib" python3 - "$TREE" "${ARGS[@]+"${ARGS[@]}"}" <<'PY'
import re, sys
from record import Record

path, args = sys.argv[1], sys.argv[2:]
rec = Record.load(path)
proto = rec.protocol()
if proto['raw'] == '':
    print("FAIL  no ## Protocol block to update", file=sys.stderr)
    sys.exit(2)

show_only = '--show' in args
add = {'questions': 0, 'fact-finders': 0, 'references': 0,
       'orchestrator reads': 0, 'lines read': 0, 'critic passes': 0}
set_ = {}
i = 0
FLAG_TO_COUNTER = {'--questions': 'questions', '--fact-finders': 'fact-finders',
                   '--references': 'references'}
while i < len(args):
    a = args[i]
    if a in FLAG_TO_COUNTER:
        add[FLAG_TO_COUNTER[a]] += int(args[i + 1]); i += 2
    elif a == '--critic-pass':
        add['critic passes'] += 1; i += 1
    elif a == '--round':
        set_['round'] = (proto['round'] or 0) + 1; i += 1
    elif a == '--set-round':
        set_['round'] = int(args[i + 1]); i += 2
    elif a == '--read':
        # One flag for one Read, so the count, the volume and the maximum
        # cannot disagree. Volume is what the guard scores: nine calls tripped
        # the old count-based threshold on a run whose largest read was 127
        # lines, while the counter that tracked size was never consulted.
        n = int(args[i + 1])
        add['orchestrator reads'] += 1
        add['lines read'] += n
        set_['largest_read'] = max(set_.get('largest_read',
                                            proto['largest_read'] or 0), n)
        i += 2
    elif a == '--next-phase':
        set_['next_phase'] = int(args[i + 1]); i += 2
    elif a == '--unlocked':
        set_['unlocked'] = args[i + 1]; i += 2
    elif a == '--show':
        i += 1
    else:
        print(f"FAIL  unhandled option: {a}", file=sys.stderr); sys.exit(2)

new = dict(proto)
for k, v in add.items():
    new[k] = (proto[k] or 0) + v
for k, v in set_.items():
    new[k] = v
new.setdefault('largest_read', proto['largest_read'])

# The record is the ground truth for the one counter derivable from it: a
# questions count below the ids on the page is a transcription error, not a
# decision, so it is corrected rather than reported.
seen = len(rec.question_ids())
if (new['questions'] or 0) < seen:
    new['questions'] = seen

def keep(pattern, default):
    m = re.search(pattern, proto['raw'])
    return m.group(1).strip() if m else default

slug    = keep(r'Slug:\s*(\S+)', new.get('slug') or 'unknown')
started = keep(r'Started:\s*(\S+)', '')
mode    = keep(r'Mode:\s*(\S+)', new.get('mode') or 'default')
stack   = keep(r'Stack:\s*([^\n]*?)\s{2,}', keep(r'Stack:\s*([^\n]*)', 'none'))
scope   = keep(r'Scope:\s*([^\n]*)', '')
rules   = keep(r'Rules in force:\s*([^\n]*)', '')
unlocked = new.get('unlocked') or keep(r'4th round unlocked:\s*(\S+)', 'no')

cap = proto['cap'] or Record.ROUND_CAP.get(mode.lower(), 3)

# The guard is arithmetic over the counters. Recomputing it here is the point:
# a guard the model can decline to trip is not a guard.
probe = Record(f"## Protocol\nMode: {mode}\nRound: {new['round']} of {cap}\n"
               f"Counters: questions {new['questions']} · fact-finders {new['fact-finders']} · "
               f"references {new['references']} · orchestrator reads {new['orchestrator reads']} · "
               f"lines read {new['lines read']} · critic passes {new['critic passes']}\n"
               f"Largest single read: {new['largest_read'] or 0} lines\n")
over = probe.guard_over()
tripped = len(over) >= 2
was_tripped = proto['guard_tripped']

block = (
    f"Slug: {slug}" + (f"   Started: {started}" if started else "") + f"   Mode: {mode}\n"
    f"Stack: {stack.strip() or 'none'}" + (f"   Scope: {scope.strip()}" if scope.strip() else "") + "\n"
    f"Round: {new['round']} of {cap}   4th round unlocked: {unlocked}   "
    f"Next phase: {new['next_phase']}\n"
    f"Counters: questions {new['questions']} · fact-finders {new['fact-finders']} · "
    f"references {new['references']} · orchestrator reads {new['orchestrator reads']} · "
    f"lines read {new['lines read']} · critic passes {new['critic passes']}\n"
    f"Largest single read: {new['largest_read'] or 0} lines\n"
    f"Guard: {'tripped — ' + ', '.join(over) if tripped else 'not tripped'}\n"
    + (f"Rules in force: {rules}\n" if rules else "")
)

if show_only:
    print(block.rstrip()); sys.exit(0)

text = rec.text
new_text, n = re.subn(r'(^## Protocol[^\n]*\n)(.*?)(?=^## |\Z)',
                      lambda m: m.group(1) + block + "\n", text, count=1, flags=re.M | re.S)
if n != 1:
    print("FAIL  could not locate the ## Protocol block to replace", file=sys.stderr)
    sys.exit(2)
with open(path, 'w') as fh:
    fh.write(new_text)

print(block.rstrip())
if tripped and not was_tripped:
    print()
    print("GUARD TRIPPED — stop grilling now (R5). Move every open and blocked")
    print("question to Deferred, say plainly that you are stopping early to")
    print("preserve room to draft, and go to Phase 5.")
    sys.exit(3)
PY
