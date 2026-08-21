#!/usr/bin/env bash
# ABOUTME: Validates a feature-spec design record (tree.md) — structure, coverage names, states and
# ABOUTME: dependency integrity. Deterministic replacement for rules the orchestrator would otherwise self-police.
set -uo pipefail

TREE="${1:-}"
[ -z "$TREE" ] && { echo "usage: check-tree.sh <path-to-tree.md>"; exit 2; }
[ -f "$TREE" ] || { echo "FAIL  no such file: $TREE"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found — check-tree.sh cannot run"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAX="$HERE/../skills/feature-spec/references/coverage-taxonomy.md"

out=$(python3 - "$TREE" "$TAX" <<'PYEOF'
import re,sys,os
tree=open(sys.argv[1]).read()
tax=open(sys.argv[2]).read() if os.path.isfile(sys.argv[2]) else ''
L=tree.splitlines()

def ok(m):   print(f"ok    {m}")
def bad(m):  print(f"FAIL  {m}")
def note(m): print(f"WARN  {m}")

def section(name):
    m=re.search(rf'^## {re.escape(name)}[^\n]*$(.*?)(?=^## |\Z)', tree, re.M|re.S)
    return m.group(1) if m else None

# ---- 1. required sections ------------------------------------------------
req=['Problem','Protocol','Reads','Coverage','Principles in force',
     'Grounding facts','Settled','Frontier','Blocked','Deferred','Sessions']
missing=[s for s in req if section(s) is None]
ok("all required sections present") if not missing else bad(f"missing sections: {missing}")

# ---- 2. protocol block ---------------------------------------------------
proto=section('Protocol') or ''
pmiss=[k for k in ('Slug:','Mode:','Round:','Next phase:','Counters:','Guard:') if k not in proto]
ok("protocol block complete") if not pmiss else bad(f"protocol missing: {pmiss}")
cmiss=[c for c in ('questions','fact-finders','references','orchestrator reads','critic passes')
       if c not in proto]
ok("all guard counters recorded") if not cmiss else bad(f"guard counters missing: {cmiss}")

# ---- 3. problem statement ------------------------------------------------
prob=[l for l in (section('Problem') or '').splitlines() if l.strip()]
ok("problem statement present") if prob else bad("## Problem is empty — drafting would invent it")

# ---- 4. coverage: names verbatim, states legal ---------------------------
want=[m.group(1).strip() for m in re.finditer(r'^\|\s*\d+\s*\|\s*\*\*(.+?)\*\*\s*\|', tax, re.M)]
cov=section('Coverage')
if cov is None:
    bad("no ## Coverage block")
else:
    rows=[(c.strip(),s.strip()) for c,s in
          re.findall(r'^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|', cov, re.M)]
    rows=[(c,s) for c,s in rows if c!='Category' and set(c)-set('- ')]
    got=[c for c,_ in rows]
    if want and got==want:
        ok(f"coverage: {len(got)} categories, names verbatim")
    elif want:
        miss=[c for c in want if c not in got]; extra=[c for c in got if c not in want]
        if miss:  bad(f"coverage missing categories: {miss}")
        if extra: bad(f"coverage has non-taxonomy names (paraphrased?): {extra}")
        if not miss and not extra: note("coverage categories are out of taxonomy order")
    LEGAL=re.compile(r'^(Clear\*|Clear|Partial|Missing|N/A)\b')
    for c,s in rows:
        if not LEGAL.match(s):
            bad(f"'{c}' has an illegal state: '{s}'"); continue
        if s.startswith('Clear*') and not re.search(r'\(\s*\d+\s+deferred\s*\)', s):
            bad(f"'{c}' is Clear* with no deferral count — must read 'Clear* (n deferred)'")
        if s.startswith('N/A') and not re.search(r'N/A\s*[—:-]\s*\S', s):
            bad(f"'{c}' is N/A with no stated reason — an unjustified N/A is a dodge")

# ---- 5. settled answers carry rationale, round -------------------------
sb=section('Settled') or ''
nset=len(re.findall(r'^\s*-\s+\*\*Q\d+', sb, re.M))
nwhy=len(re.findall(r'^\s*\*Why:\*', sb, re.M))
nrnd=len(re.findall(r'\(r\d+\)', sb))
if nset==0:
    note("no settled answers yet (expected before round 1)")
else:
    ok(f"all {nset} settled answers carry a rationale") if nwhy>=nset else \
        bad(f"{nset} settled answers but {nwhy} rationales — the rationale is what a compaction destroys")
    ok("all settled answers carry a round tag") if nrnd>=nset else \
        bad(f"{nset} settled answers but {nrnd} round tags (rN)")

# ---- 6. question ids unique ---------------------------------------------
ids=re.findall(r'\*\*(Q\d+)', tree)
dup=sorted({i for i in ids if ids.count(i)>1})
ok("question ids unique") if not dup else bad(f"question id reused: {dup}")

# ---- 7. transitive deferral ---------------------------------------------
deferred=set(re.findall(r'\*\*(Q\d+)', section('Deferred') or ''))
orphans=[]
for line in (section('Blocked') or '').splitlines():
    qm=re.search(r'\*\*(Q\d+)', line)
    if not qm or 'deps:' not in line: continue
    for dep in re.findall(r'\bQ\d+\b', line.split('deps:')[-1]):
        if dep in deferred: orphans.append(f"{qm.group(1)}->{dep}")
ok("no blocked question waits on a deferred parent") if not orphans else \
    bad(f"deferral not transitive — orphans in Blocked: {', '.join(orphans)}")

# ---- 8. history overflow -------------------------------------------------
n=len(L)
if n>400 and section('History') is None:
    note(f"{n} lines and no ## History section — move superseded Settled entries there")
else:
    ok(f"size {n} lines")
PYEOF
)

status=$?
if [ "$status" -ne 0 ]; then
  [ -n "$out" ] && echo "$out"
  echo "FAIL  checker did not run to completion (python3 exited $status)"
  exit 2
fi

echo "$out"
fail=$(printf '%s\n' "$out" | grep -c '^FAIL' || true)
warn=$(printf '%s\n' "$out" | grep -c '^WARN' || true)

echo
if [ "$fail" -eq 0 ]; then
  if [ "$warn" -gt 0 ]; then echo "TREE OK ($warn warning(s))"; else echo "TREE OK"; fi
  exit 0
else
  echo "$fail PROBLEM(S) — fix before the next round"; exit 1
fi
