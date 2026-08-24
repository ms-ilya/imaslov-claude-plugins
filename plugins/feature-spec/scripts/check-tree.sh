#!/usr/bin/env bash
# ABOUTME: Validates a feature-spec design record (tree.md) — structure, coverage names, states,
# ABOUTME: counter values and dependency integrity. Deterministic replacement for rules the orchestrator would self-police.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: check-tree.sh <path-to-tree.md> [--repo-root <path>] [--doctor]

  --repo-root <path>  Root the ## Reads entries are resolved against.
                      Defaults to the enclosing git work tree, else the
                      current directory.
  --closed-world      Check only what the record ASSERTS, never what it OMITS.
                      Phase 1 legitimately writes four sections and no more;
                      Phase 2 adds the rest. Open-world checks fail on every
                      honest intermediate state, which teaches the writer to
                      evade the checker rather than satisfy it. Used by the
                      PostToolUse hook; the full check runs at the round gate.
  --doctor            Diagnose an unparseable record: name every section that
                      is missing or malformed, print the shape it should have
                      straight from tree-format.md, and say what the minimal
                      repair is. Reports; never edits.
USAGE
}

TREE=""
ROOT=""
DOCTOR=0
CLOSED=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --doctor) DOCTOR=1; shift ;;
    --closed-world) CLOSED=1; shift ;;
    --repo-root)
      [ $# -ge 2 ] || { echo "FAIL  --repo-root needs a path"; exit 2; }
      ROOT="$2"; shift 2 ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *)
      [ -z "$TREE" ] || { echo "FAIL  unexpected extra argument: $1"; usage; exit 2; }
      TREE="$1"; shift ;;
  esac
done

[ -z "$TREE" ] && { usage; exit 2; }
[ -f "$TREE" ] || { echo "FAIL  no such file: $TREE"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found — check-tree.sh cannot run"; exit 2; }

# The ## Reads list is what Phase 5 opens, and it is written relative to the repo
# root rather than to the record. Resolving it anywhere else turns a real file into
# a reported ghost, which is worse than not checking at all — and a false ghost is
# the failure that teaches a writer to route around the checker.
#
# The process cwd is NOT a safe fallback: a hook runs in the session's directory,
# which has nothing to do with the file being written. So a root is derived from
# the record's own location, and every ancestor is tried before anything is called
# missing. A path invented out of nothing still resolves nowhere.
if [ -z "$ROOT" ]; then
  ROOT="$(git -C "$(dirname "$TREE")" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$ROOT" ] || ROOT="$(cd "$(dirname "$TREE")" && pwd)"
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAX="$HERE/../skills/feature-spec/references/coverage-taxonomy.md"
FMT="$HERE/../skills/feature-spec/references/tree-format.md"

if [ "$DOCTOR" -eq 1 ]; then
  # "Report which section failed and stop" is the right behaviour and also a dead
  # end: the user is left holding a corrupted record with no route back. The
  # repair text comes from the shipped skeleton, so it cannot drift from the format.
  PYTHONPATH="$HERE/lib" python3 - "$TREE" "$FMT" "$TAX" <<'DOCEOF'
import re, sys
from record import Record

rec = Record.load(sys.argv[1])
skel = ''
try:
    m = re.search(r'```skeleton\n(.*?)\n```', open(sys.argv[2]).read(), re.S)
    skel = m.group(1) if m else ''
except OSError:
    pass

def skel_section(name):
    m = re.search(rf'^## {re.escape(name)}[^\n]*$(.*?)(?=^## |\Z)', skel, re.M | re.S)
    return (f"## {name}" + m.group(1).rstrip()) if m else None

problems = 0
print(f"DOCTOR  {sys.argv[1]}")
print()

missing = rec.missing_sections()
if missing:
    problems += len(missing)
    print(f"{len(missing)} required section(s) missing: {', '.join(missing)}")
    print()
    for name in missing:
        block = skel_section(name)
        print(f"── add ── {name}")
        if block:
            for line in block.splitlines():
                print(f"   {line}")
        else:
            print(f"   ## {name}")
            print("   (tree-format.md has no example for this section)")
        print()

if not rec.problem():
    problems += 1
    print("── repair ── ## Problem is empty")
    print("   One line: whose problem, and what changes for them. Drafting")
    print("   invents the problem statement without it, which is the single")
    print("   worst thing for it to invent.")
    print()

want = [m.group(1).strip() for m in
        re.finditer(r'^\|\s*\d+\s*\|\s*\*\*(.+?)\*\*\s*\|', open(sys.argv[3]).read(), re.M)]
got = [c for c, _ in rec.coverage()]
if want and got != want:
    problems += 1
    print("── repair ── ## Coverage does not match the taxonomy")
    if not got:
        print("   No parseable table. Replace the section with:")
    else:
        for c in [c for c in want if c not in got]:
            print(f"   missing:   {c}")
        for c in [c for c in got if c not in want]:
            print(f"   not a category (paraphrased?):   {c}")
        print("   The names must be verbatim. Canonical table:")
    print()
    print("   | Category | Status |")
    print("   |---|---|")
    for c in want:
        print(f"   | {c} | Missing |")
    print()

p = rec.protocol()
if p['raw'] and p['round'] is None:
    problems += 1
    print("── repair ── ## Protocol has no readable Round")
    print("   Run:  bump-protocol.sh <tree.md> --set-round <n> --next-phase <n>")
    print("   which rewrites the whole block in canonical form.")
    print()

print("─────────────────────────────────────────────")
if problems == 0:
    print("Nothing structurally wrong. Run without --doctor for the full check.")
    sys.exit(0)
print(f"{problems} structural problem(s).")
print("Apply the blocks above, then re-run without --doctor.")
print("If the record is beyond repair, archive it as tree.archived-<date>.md")
print("and restart — never guess at a corrupted design record.")
sys.exit(1)
DOCEOF
  exit $?
fi

out=$(PYTHONPATH="$HERE/lib" python3 - "$TREE" "$TAX" "$ROOT" "$CLOSED" <<'PYEOF'
import re,sys,os
from record import Record, is_external_path
tree=open(sys.argv[1]).read()
rec=Record(tree, sys.argv[1])
tax=open(sys.argv[2]).read() if os.path.isfile(sys.argv[2]) else ''
root=sys.argv[3]
# Closed-world: assert only about content that is present, never about absence.
# A record is built across phases; a section that does not exist yet is not wrong.
closed=sys.argv[4]=='1'
def skipped(label):
    print(f"skip  {label} (open-world — not checked on a partial record)")
L=tree.splitlines()

fail=warn=0
def ok(m):   print(f"ok    {m}")
def bad(m,expected=None):
    global fail; print(f"FAIL  {m}"); fail+=1
    # A finding without the shape it wanted makes the caller reconstruct the format
    # from memory, which is one more place interpretation drifts.
    if expected:
        for line in expected.splitlines(): print(f"      expected: {line}")
def note(m):
    global warn; print(f"WARN  {m}"); warn+=1

def section(name):
    m=re.search(rf'^## {re.escape(name)}[^\n]*$(.*?)(?=^## |\Z)', tree, re.M|re.S)
    return m.group(1) if m else None

# ---- 1. required sections ------------------------------------------------
req=['Problem','Protocol','Reads','Coverage','Principles in force',
     'Grounding facts','Settled','Frontier','Blocked','Deferred','Sessions']
missing=[s for s in req if section(s) is None]
if closed:
    skipped(f"all required sections present ({len(missing)} not yet written)")
elif not missing:
    ok("all required sections present")
else:
    bad(f"missing sections: {missing}", "a '## <name>' heading for each, in tree-format.md order")

# ---- 2. protocol block ---------------------------------------------------
PROTO_SHAPE=("Round: 2 of 3   4th round unlocked: no   Next phase: 2\n"
             "Counters: questions 10 · fact-finders 2 · references 4 · "
             "orchestrator reads 5 · lines read 340 · critic passes 0\n"
             "Largest single read: 180 lines\n"
             "Guard: not tripped")
proto=section('Protocol') or ''
pmiss=[k for k in ('Slug:','Mode:','Round:','Next phase:','Counters:','Guard:') if k not in proto]
if closed and pmiss:
    skipped(f"protocol block complete ({len(pmiss)} field(s) not yet written)")
elif not pmiss:
    ok("protocol block complete")
else:
    bad(f"protocol missing: {pmiss}", PROTO_SHAPE)
CTRS=Record.COUNTERS
cmiss=[c for c in CTRS if c not in proto]
if closed and cmiss:
    skipped("all guard counters recorded")
elif not cmiss:
    ok("all guard counters recorded")
else:
    bad(f"guard counters missing: {cmiss}", PROTO_SHAPE)

# ---- 3. problem statement ------------------------------------------------
prob=[l for l in (section('Problem') or '').splitlines() if l.strip()]
if prob:
    ok("problem statement present")
elif closed:
    skipped("problem statement present")
else:
    bad("## Problem is empty — drafting would invent it",
        "one line: whose problem, and what changes for them")

# ---- 4. coverage: names verbatim, states legal ---------------------------
want=[m.group(1).strip() for m in re.finditer(r'^\|\s*\d+\s*\|\s*\*\*(.+?)\*\*\s*\|', tax, re.M)]
cov=section('Coverage')
if cov is None and closed:
    skipped("coverage table")
elif cov is None:
    bad("no ## Coverage block", "| Category | Status |")
else:
    rows=[(c.strip(),s.strip()) for c,s in
          re.findall(r'^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|', cov, re.M)]
    rows=[(c,s) for c,s in rows if c!='Category' and set(c)-set('- ')]
    got=[c for c,_ in rows]
    if want and got==want:
        ok(f"coverage: {len(got)} categories, names verbatim")
    elif want:
        miss=[c for c in want if c not in got]; extra=[c for c in got if c not in want]
        if miss:  bad(f"coverage missing categories: {miss}",
                      "the taxonomy's category names, verbatim — paraphrase breaks comparability")
        if extra: bad(f"coverage has non-taxonomy names (paraphrased?): {extra}",
                      "the taxonomy's category names, verbatim")
        if not miss and not extra: note("coverage categories are out of taxonomy order")
    LEGAL=re.compile(r'^(Clear\*|Clear|Partial|Missing|N/A)\b')
    for c,s in rows:
        if not LEGAL.match(s):
            bad(f"'{c}' has an illegal state: '{s}'", "one of: Clear | Clear* (n deferred) | Partial | Missing | N/A — <reason>")
            continue
        if s.startswith('Clear*') and not re.search(r'\(\s*\d+\s+deferred\s*\)', s):
            bad(f"'{c}' is Clear* with no deferral count", "Clear* (2 deferred)")
        if s.startswith('N/A') and not re.search(r'N/A\s*[—:-]\s*\S', s):
            bad(f"'{c}' is N/A with no stated reason — an unjustified N/A is a dodge",
                "N/A — makes no network calls and reads no external data")

# ---- 5. settled answers carry rationale, round -------------------------
sb=section('Settled') or ''
nset=len(re.findall(r'^\s*-\s+\*\*Q\d+', sb, re.M))
nwhy=len(re.findall(r'^\s*\*Why:\*', sb, re.M))
nrnd=len(re.findall(r'\(r\d+\)', sb))
SETTLED_SHAPE=("- **Q2 Attempt ceiling** → at most 5 attempts spread over 24h. [P2]\n"
               "  *Why:* survives a workday outage, bounds file growth. (r1)")
if nset==0:
    note("no settled answers yet (expected before round 1)")
else:
    ok(f"all {nset} settled answers carry a rationale") if nwhy>=nset else \
        bad(f"{nset} settled answers but {nwhy} rationales — the rationale is what a compaction destroys",
            SETTLED_SHAPE)
    ok("all settled answers carry a round tag") if nrnd>=nset else \
        bad(f"{nset} settled answers but {nrnd} round tags (rN)", SETTLED_SHAPE)

# ---- 6. question ids unique ---------------------------------------------
# Struck-through text is retracted or superseded, not live. Rule 5 keeps a
# superseded answer in place as ~~...~~ with the new one beneath it, and
# undo-round.sh strikes a retracted answer and returns its question to the
# frontier. Counting struck ids would make both of those legal moves report as a
# reused identifier, which is the opposite of what the rule asks for.
live=re.sub(r'~~.*?~~', '', tree)
ids=re.findall(r'\*\*(Q\d+)', live)
dup=sorted({i for i in ids if ids.count(i)>1})
ok("question ids unique") if not dup else \
    bad(f"question id reused: {dup}", "each Q<n> names one question for the life of the file")

# ---- 7. transitive deferral ---------------------------------------------
deferred=set(re.findall(r'\*\*(Q\d+)', section('Deferred') or ''))
orphans=[]
for line in (section('Blocked') or '').splitlines():
    qm=re.search(r'\*\*(Q\d+)', line)
    if not qm or 'deps:' not in line: continue
    for dep in re.findall(r'\bQ\d+\b', line.split('deps:')[-1]):
        if dep in deferred: orphans.append(f"{qm.group(1)}->{dep}")
ok("no blocked question waits on a deferred parent") if not orphans else \
    bad(f"deferral not transitive — orphans in Blocked: {', '.join(orphans)}",
        "move the whole blocked subtree to ## Deferred in one step")

# ---- 8. counter VALUES, not just their presence --------------------------
# Presence-checking the counters makes the guard unfalsifiable: a stale block
# reports a round the interview never reached and a question count of zero, and
# the guard reads its thresholds from exactly these numbers.
def num(pat, hay, cast=int):
    m=re.search(pat, hay)
    return cast(m.group(1)) if m else None

mode=(num(r'Mode:\s*(\S+)', proto, str) or '').strip().lower()
CAP=Record.ROUND_CAP
rnd=num(r'Round:\s*(\d+)', proto)
cap=num(r'Round:\s*\d+\s*of\s*(\d+)', proto)
nextp=num(r'Next phase:\s*(\d+)', proto)
qc=num(r'questions\s+(\d+)', proto)
guard_tripped = bool(re.search(r'Guard:\s*tripped', proto, re.I))

problems=[]
if rnd is not None and rnd < 1 and not closed:
    problems.append(f"Round is {rnd} — a record exists, so at least round 1 has been rendered")
if mode in CAP and rnd is not None and rnd > CAP[mode]:
    problems.append(f"Round {rnd} exceeds the hard ceiling for mode '{mode}' ({CAP[mode]})")
if cap is not None and rnd is not None and rnd > cap:
    problems.append(f"Round {rnd} is past the declared cap of {cap}")
if nextp is not None and not 0 <= nextp <= 7:
    problems.append(f"Next phase: {nextp} — the pipeline has phases 0 through 7")
# The record is the ground truth for the two counters derivable from it.
seen_q=len(set(re.findall(r'\*\*(Q\d+)', tree)))
if qc is not None and seen_q > qc:
    problems.append(f"questions counter is {qc} but {seen_q} distinct question ids appear in the record")
if rnd is not None and nrnd:
    highest=max(int(m) for m in re.findall(r'\(r(\d+)\)', sb))
    if highest > rnd:
        problems.append(f"a settled answer is tagged (r{highest}) but Round says {rnd}")
if problems:
    for p in problems: bad(f"protocol counter: {p}", PROTO_SHAPE)
else:
    ok("protocol counters are internally consistent")

# ---- 8b. the guard's own arithmetic --------------------------------------
# Thresholds come from record.py so the checker and bump-protocol.sh cannot
# disagree about what "at threshold" means, and they are mode-relative: a fixed
# fact-finder threshold scored the mode's own mandate rather than the interview.
over=rec.guard_over()
if len(over)>=2 and not guard_tripped:
    bad(f"guard says 'not tripped' but {len(over)} counters are at threshold: {', '.join(over)}",
        "Guard: tripped   — then stop grilling, defer the open questions and go to Phase 5 (R5)")
elif len(over)<2 and guard_tripped:
    note(f"guard says 'tripped' but only {len(over)} counter(s) are at threshold — early stops are allowed, just confirm it was deliberate")
else:
    ok(f"guard state agrees with the counters ({len(over)} at threshold)")

# ---- 9. every ## Reads entry resolves to a real file ---------------------
# Phase 5 opens tree.md plus exactly these files, often in a fresh session. A
# ghost entry becomes a failed Read at drafting time, which is the worst place
# to find it: the interview is over and the user has gone.
paths=rec.reads()
if not paths:
    note("## Reads lists no files — drafting will open only tree.md")
else:
    # Try the derived root, then every ancestor of it. A real file resolves
    # against one of them; an invented one resolves against none. The resolution
    # itself — including the external-path rule a principles file in ~ depends on
    # — lives in Record.ghost_reads, because a second copy of it here is a second
    # thing to keep in step with tree-format.md.
    ancestors=[]
    cur=os.path.abspath(root)
    while True:
        parent=os.path.dirname(cur)
        if parent==cur: break
        ancestors.append(parent); cur=parent
    ghosts=rec.ghost_reads(root, ancestors)
    external=[p for p in paths if is_external_path(p) and p not in ghosts]
    if ghosts:
        for g in ghosts:
            bad(f"## Reads names a file that does not exist: {g}",
                (f"an absolute or ~-prefixed path that exists on this machine"
                 if is_external_path(g) else f"a path relative to {root}, or remove the entry"))
    else:
        ok(f"all {len(paths)} ## Reads entries resolve"
           + (f" ({len(external)} outside the repo)" if external else ""))

# ---- 10. history overflow ------------------------------------------------
n=len(L)
if n>400 and section('History') is None:
    note(f"{n} lines and no ## History section — move superseded Settled entries there")
else:
    ok(f"size {n} lines")

print()
mode=' (closed-world)' if closed else ''
if fail==0:
    print(f"TREE OK{mode}{f' ({warn} warning(s))' if warn else ''}"); sys.exit(0)
print(f"{fail} PROBLEM(S) — fix before the next round"); sys.exit(1)
PYEOF
)

status=$?

# 0 = clean, 1 = findings the checker reported. Anything else means it never ran,
# and a checker that did not run must not read as a pass.
if [ "$status" -gt 1 ]; then
  [ -n "$out" ] && echo "$out"
  echo "FAIL  checker did not run to completion (python3 exited $status)"
  exit 2
fi

echo "$out"
exit "$status"
