#!/usr/bin/env bash
# ABOUTME: Validates a feature-spec design record (tree.md) — structure, coverage names, states,
# ABOUTME: round values and dependency integrity. Deterministic replacement for rules the orchestrator would self-police.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: check-tree.sh <path-to-tree.md> [--repo-root <path>] [--closed-world] [--doctor]

  --repo-root <path>  Root the ## Reads entries and the grounding facts'
                      path:line citations are resolved against.
                      Defaults to the enclosing git work tree, else the
                      current directory.
  --closed-world      Check only what the record ASSERTS, never what it OMITS.
                      Intake legitimately writes only some sections;
                      Phase 2 adds the rest. Open-world checks fail on every
                      honest intermediate state, which teaches the writer to
                      evade the checker rather than satisfy it. Used by the
                      PostToolUse hook; the full check runs at the gate.
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
[ -f "$TAX" ] || { echo "FAIL  coverage taxonomy not found: $TAX"; exit 2; }

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

def skel_heading(name):
    m = re.search(rf'^## {re.escape(name)}[^\n]*$', skel, re.M)
    return m.group(0) if m else f"## {name}"

problems = 0
print(f"DOCTOR  {sys.argv[1]}")
print()

missing = rec.missing_sections()
if missing:
    problems += len(missing)
    print(f"{len(missing)} required section(s) missing: {', '.join(missing)}")
    print()
    for name in missing:
        print(f"── add ── {name}")
        print(f"   {skel_heading(name)}")
        if name == 'Protocol':
            print("   Slug: <directory name>   Started: <date>")
            print("   Stack: <stack or none>   Scope: <path or none>")
            print("   Round: <n> of <m>   Next phase: <n>")
        print()
    # The skeleton's body is an example about another feature. Pasted into a
    # real record it becomes decisions nobody made, which every tag then resolves.
    print("Add the heading only. What the section held comes back from the input")
    print("or from the user, never from the example in tree-format.md.")
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
    print("   Add the line:  Round: <n> of <m>   Next phase: <n>")
    print("   where n is the number of clarifying rounds already answered.")
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
from record import (Record, is_external_path, search_roots, resolve_path,
                    wording_overlap, FACT_SUFFIX, FACT_VERDICT)
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
PROTO_SHAPE=("Slug: 2026-08-21-retry-uploads   Started: 2026-08-21\n"
             "Round: 1 of 2   Next phase: 2")
proto=section('Protocol') or ''
pmiss=[k for k in ('Slug:','Round:','Next phase:') if k not in proto]
if closed and pmiss:
    skipped(f"protocol block complete ({len(pmiss)} field(s) not yet written)")
elif not pmiss:
    ok("protocol block complete")
else:
    bad(f"protocol missing: {pmiss}", PROTO_SHAPE)

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
    # A table can only be as clear as the record under it. Both checks need the
    # rest of the record to exist, so they wait for the gate.
    if not closed:
        claimed=sum(int(m.group(1)) for _,s in rows if s.startswith('Clear*')
                    for m in [re.search(r'\(\s*(\d+)\s+deferred\s*\)', s)] if m)
        ndef=len(rec.deferred_entries())
        if claimed>ndef:
            bad(f"coverage counts {claimed} deferred question(s) across its Clear* rows, but ## Deferred lists {ndef}",
                "each Clear* count names questions that sit under ## Deferred")
        if any(s.startswith('Clear') for _,s in rows) and not rec.settled() \
                and not rec.grounding_fact_list():
            bad("coverage scores a category Clear, but the record holds no settled decision and no grounding fact",
                "Clear means every decision in the category is made and written down")

# ---- 5. settled answers carry rationale, round -------------------------
SETTLED_SHAPE=("- **Q2 Attempt ceiling** → at most 5 attempts spread over 24h. [P2]\n"
               "  *Why:* survives a workday outage, bounds file growth. (r1)")
DEFERRED_SHAPE="- **Q12 Per-source overrides** — low impact, decided post-launch (r1)"
# An entry the parser cannot read looks settled to a person and does not exist
# for any tool: no tag resolves to it and no packet carries it.
for name,shape in (('Settled',SETTLED_SHAPE),('Deferred',DEFERRED_SHAPE)):
    for line in rec.unparsed_entries(name):
        bad(f"an entry under ## {name} cannot be read: '{line[:60]}'", shape)
settled=rec.settled()
nset=len(settled)
rounds=[e['round'] for e in settled if e['round'] is not None]
if nset==0:
    note("no settled answers yet")
else:
    noans=[e['id'] for e in settled if not e['answer']]
    nowhy=[e['id'] for e in settled if not e['why']]
    nornd=[e['id'] for e in settled if e['round'] is None]
    if noans:
        bad(f"settled with no answer: {', '.join(noans)}", SETTLED_SHAPE)
    ok(f"all {nset} settled answers carry a rationale") if not nowhy else \
        bad(f"settled with no rationale: {', '.join(nowhy)} — the rationale is what a compaction destroys",
            SETTLED_SHAPE)
    ok("all settled answers carry a round tag") if not nornd else \
        bad(f"settled with no round tag (rN): {', '.join(nornd)}", SETTLED_SHAPE)
for d in rec.deferred_entries():
    if not re.sub(r'\(r\d+\)', '', d['reason']).strip(' .—-'):
        bad(f"{d['id']} is deferred with no reason — the reason is what its marker in the spec says",
            DEFERRED_SHAPE)

# ---- 6. question ids unique ---------------------------------------------
# Struck-through text is superseded, not live. Rule 5 keeps a superseded answer
# in place as ~~...~~ with the new one beneath it. Counting struck ids would make
# that legal move report as a reused identifier, which is the opposite of what
# the rule asks for.
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

# ---- 8. round and phase VALUES, not just their presence -------------------
# A stale block reports a round the run never reached, and --resume re-enters
# from exactly these numbers.
#
# Round 0 is legal: input that already covers every category gets no clarifying
# round. The ceiling is the one the record declares, because an amendment
# continues the numbering of the session before it.
def num(pat, hay, cast=int):
    m=re.search(pat, hay)
    return cast(m.group(1)) if m else None

rnd=num(r'Round:\s*(\d+)', proto)
cap=num(r'Round:\s*\d+\s*of\s*(\d+)', proto)
nextp=num(r'Next phase:\s*(\d+)', proto)

problems=[]
if 'Round:' in proto and (rnd is None or cap is None):
    problems.append("Round is not written as 'Round: <n> of <m>'")
if 'Next phase:' in proto and nextp is None:
    problems.append("Next phase is not a number")
if cap is not None and rnd is not None and rnd > cap:
    problems.append(f"Round {rnd} is past the declared cap of {cap}")
if nextp is not None and not 0 <= nextp <= 7:
    problems.append(f"Next phase: {nextp} — the pipeline has phases 0 through 7")
if rnd is not None and rounds:
    highest=max(rounds)
    if highest > rnd:
        problems.append(f"a settled answer is tagged (r{highest}) but Round says {rnd}")
if problems:
    for p in problems: bad(f"protocol: {p}", PROTO_SHAPE)
else:
    ok("protocol round and phase are consistent with the record")

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
    ghosts=rec.ghost_reads(root, search_roots(root)[1:])
    external=[p for p in paths if is_external_path(p) and p not in ghosts]
    if ghosts:
        for g in ghosts:
            bad(f"## Reads names a file that does not exist: {g}",
                (f"an absolute or ~-prefixed path that exists on this machine"
                 if is_external_path(g) else f"a path relative to {root}, or remove the entry"))
    else:
        ok(f"all {len(paths)} ## Reads entries resolve"
           + (f" ({len(external)} outside the repo)" if external else ""))

# ---- 9b. a decision taken from the input keeps the input's wording --------
# An (r0) entry is what every requirement citing it is later compared with. One
# written from a document says which, so its answer can be held against that
# document here: a paraphrase is a new decision nobody made, and nothing
# downstream has the document to notice.
if rnd is not None and cap is not None:
    first_session = cap - 2 <= 0
    doc_text = {}
    for p_ in rec.reads():
        full = resolve_path(p_, search_roots(root))
        if full and os.path.isfile(full):
            with open(full, errors='replace') as fh:
                doc_text[p_] = fh.read()
    r0_checked = 0; r0_fail = fail; unsourced = []
    for e in settled:
        if e['round'] != 0:
            continue
        named = [p_ for p_ in doc_text if p_ in e['why'] or os.path.basename(p_) in e['why']]
        if not named:
            if 'request' not in e['why'].lower():
                unsourced.append(e['id'])
            continue
        share = max((wording_overlap(e['answer'], doc_text[p_]) for p_ in named),
                    key=lambda v: -1 if v is None else v)
        if share is None:
            continue
        r0_checked += 1
        if share < 0.5:
            msg = (f"{e['id']} is said to come from {named[0]}, but only {share:.0%} of its answer is that "
                   f"document's wording — an (r0) answer is the sentence that decides, copied, not a summary of it")
            bad(msg, "the document's own words after the arrow; trim around them, add nothing") \
                if first_session else note(msg + " (the document may have changed since)")
    if unsourced:
        msg = (f"tagged (r0) without saying where the decision came from: {', '.join(unsourced)}")
        shape = ("*Why:* <reason>. From docs/briefs/retry.md, \"Decided\". (r0)   — the path as ## Reads lists it\n"
                 "*Why:* <reason>. Stated in the request. (r0)")
        bad(msg, shape) if first_session else note(msg)
    if r0_checked and fail == r0_fail:
        ok(f"{r0_checked} decision(s) taken from an input document keep its wording")

# ---- 10. grounding facts: numbered once, sourced, citing real lines -------
# Every requirement that cites a fact inherits whatever is wrong with it, and
# nothing downstream opens the file again. A path that is not on disk, or a line
# past the end of the file, was never read by whoever reported it.
flist=rec.grounding_fact_list()
nums=[n for n,_ in flist]
dupf=sorted({n for n in nums if nums.count(n)>1}, key=int)
if dupf:
    bad(f"grounding fact number used twice: {', '.join(dupf)} — a tag naming it cannot say which one it means",
        "each fact keeps its own number")
roots=search_roots(root)
scope=num(r'Scope:\s*(\S+)', proto, str)
# Facts from an earlier session describe the code as it was then. They are
# reported, not failed: only this session's facts can have been checked today.
session_start=cap-2 if cap is not None else 0
n_cites=0; fact_fail=fail
for n,text in flist:
    src=FACT_SUFFIX.search(text)
    if not src:
        bad(f"grounding fact {n} does not say where it came from",
            "<fact> (fact-finder, r0, high)   or   <fact> (read at intake, r0, high)")
    current=src is None or int(src.group(2))>=session_start
    refuted=FACT_VERDICT.search(text) is not None
    for path,line in rec.fact_citations(text):
        n_cites+=1
        full=resolve_path(path, roots)
        if full is None and scope and scope!='none' and not is_external_path(path):
            full=resolve_path(os.path.join(scope, path), roots)
        if full is None:
            if '/' in path and current and not refuted:
                bad(f"grounding fact {n} cites {path}:{line}, and no such file exists — a fact is recorded from a file that was opened",
                    "the path as it is on disk, from the repository root")
            else:
                note(f"grounding fact {n} cites {path}:{line}, which was not found"
                     + ("" if '/' in path else " — write the path from the repository root so it can be checked"))
            continue
        if not os.path.isfile(full):
            continue
        with open(full, errors='replace') as fh:
            length=sum(1 for _ in fh)
        if line>length:
            msg=f"grounding fact {n} cites line {line} of {path}, which has {length} lines"
            bad(msg, "the line the fact was read from") if current else note(msg + " — it may have changed since")
if flist and fail==fact_fail:
    ok(f"{len(flist)} grounding fact(s) sourced" + (f", {n_cites} citation(s) point at real lines" if n_cites else ""))

# ---- 11. history overflow ------------------------------------------------
n=len(L)
if n>400 and section('History') is None:
    note(f"{n} lines and no ## History section — move superseded Settled entries there")
else:
    ok(f"size {n} lines")

print()
mode=' (closed-world)' if closed else ''
if fail==0:
    print(f"TREE OK{mode}{f' ({warn} warning(s))' if warn else ''}"); sys.exit(0)
print(f"{fail} PROBLEM(S) — fix before going on"); sys.exit(1)
PYEOF
)

status=$?

# 0 = clean, 1 = findings the checker reported. A crash also exits 1, with no
# result line, and a checker that did not reach a verdict must not read as a
# list of findings or as a pass.
if [ "$status" -gt 1 ] || ! printf '%s\n' "$out" | grep -qE '^(TREE OK|[0-9]+ PROBLEM)'; then
  [ -n "$out" ] && echo "$out"
  echo "FAIL  checker did not reach a verdict (python3 exited $status)"
  exit 2
fi

echo "$out"
exit "$status"
