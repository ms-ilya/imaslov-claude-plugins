#!/usr/bin/env bash
# ABOUTME: Validates a drafted feature spec — source tags on every requirement, identifier stability,
# ABOUTME: acceptance coverage and unquantified adjectives. Enforces R10 deterministically, before the critic runs.
set -uo pipefail

SPEC="${1:-}"
PREV="${2:-}"     # optional: a previous spec.md, to catch renumbering
[ -z "$SPEC" ] && { echo "usage: check-spec.sh <path-to-spec.md> [previous-spec.md]"; exit 2; }
[ -f "$SPEC" ] || { echo "FAIL  no such file: $SPEC"; exit 2; }
# A previous spec that was asked for but cannot be read must not silently disable the
# renumber check — that check is the whole point of passing it on an amendment.
if [ -n "$PREV" ] && [ ! -f "$PREV" ]; then
  echo "FAIL  previous spec not found: $PREV"
  echo "      pass the real path to the existing spec.md, or pass nothing at all"
  exit 2
fi
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found — check-spec.sh cannot run"; exit 2; }

out=$(python3 - "$SPEC" "$PREV" <<'PY'
import re,sys,os
spec=open(sys.argv[1]).read()
prev=open(sys.argv[2]).read() if len(sys.argv)>2 and sys.argv[2] and os.path.isfile(sys.argv[2]) else None
fail=warn=0
def bad(m):
    global fail; print(f"FAIL  {m}"); fail+=1
def note(m):
    global warn; print(f"WARN  {m}"); warn+=1
def ok(m): print(f"ok    {m}")

lines=spec.splitlines()

# ---- sections -------------------------------------------------------------
# Identifiers are DEFINED only under ## Requirements and ## Success criteria.
# Everywhere else — acceptance scenarios, clarifications, out of scope — an
# FR-NNN is a reference. Splitting on the heading is what keeps the two apart;
# matching the heading loosely is what stops a capitalisation slip from turning
# every scenario into a duplicate definition.
def norm(h): return re.sub(r'[^a-z ]',' ',h.lower()).strip()
DEF_HEADS  = ('requirements','functional requirements','success criteria')
SCEN_HEADS = ('acceptance scenarios','acceptance criteria')

sections=[]                      # (normalised heading, first line idx, last line idx)
cur=None
for i,l in enumerate(lines):
    m=re.match(r'^##\s+(.*?)\s*$', l)
    if not m: continue
    if cur: sections.append((cur[0],cur[1],i-1))
    cur=(norm(m.group(1)), i+1)
if cur: sections.append((cur[0],cur[1],len(lines)-1))

def span(names):
    return [(a,b) for h,a,b in sections if h in names]

def_spans  = span(DEF_HEADS)
scen_spans = span(SCEN_HEADS)

if not def_spans:
    bad("no '## Requirements' or '## Success criteria' section — is this a drafted spec?")
    print(); print("1 PROBLEM(S) — fix before writing"); sys.exit(1)

# ---- collect requirements and criteria, with the tag that follows them ----
VALID=re.compile(r'←\s*(Settled\s+Q\d+|Grounding fact\s+\d+|Strategy \(chosen\)|'
                 r'Principle:\s*\S+|ADR-\S+|[\w./-]+\.md)')
# Tolerant of the markdown decoration a drafter reaches for by reflex: a bullet,
# bold, a colon. An identifier the parser cannot see is an identifier it cannot
# check, and a check that silently examines nothing reports a pass it never made.
DEF=re.compile(r'^\s*(?:[-*+]\s+)?\*{0,2}((?:FR|SC)-\d+[a-z]?)\*{0,2}\s*[:—–-]?\s+(\S.*)$')
MENTION=re.compile(r'(?:FR|SC)-\d')

items=[]                       # (id, text, tagline or None, lineno)
claimed=set()
for a,b in def_spans:
    for i in range(a, b+1):
        m=DEF.match(lines[i])
        if not m: continue
        ident,text=m.group(1),m.group(2)
        claimed.add(i)
        tag=lines[i] if '←' in lines[i] else None
        if tag is None:
            for j in range(i+1, min(i+4,len(lines))):
                if '←' in lines[j]: tag=lines[j]; break
                if DEF.match(lines[j]): break
        items.append((ident,text,tag,i+1))

# ---- nothing in a definition section names an id the parser could not read --
orphans=[(i+1,lines[i].strip()[:60]) for a,b in def_spans for i in range(a,b+1)
         if i not in claimed and MENTION.search(lines[i]) and '←' not in lines[i]]
if orphans:
    for n,txt in orphans:
        bad(f"line {n} names an identifier the checker could not parse as a definition: '{txt}'")
    bad("unparsed identifiers mean the checks below examined less than the whole spec — "
        "write each one as 'FR-001  <statement>' on its own line")
else:
    ok("every identifier in the requirement sections parsed")

if not items:
    bad("requirement sections contain no FR-NNN or SC-NNN identifiers")
    print(); print(f"{fail} PROBLEM(S) — fix before writing"); sys.exit(1)

frs=[x for x in items if x[0].startswith('FR')]
scs=[x for x in items if x[0].startswith('SC')]
ok(f"found {len(frs)} requirements, {len(scs)} success criteria")
if not frs: bad("no FR-NNN requirements found — a spec with no requirements is not a spec")

# ---- R10: every statement carries a VALID source tag ---------------------
untagged=[(i,n) for i,t,tag,n in items if not tag]
invalid =[(i,n) for i,t,tag,n in items if tag and not VALID.search(tag)]
withdrawn={i for i,t,_,_ in items if 'withdrawn' in t.lower()}
marked  ={i for i,t,_,_ in items if 'NEEDS CLARIFICATION' in t}
exempt=withdrawn|marked
untagged=[(i,n) for i,n in untagged if i not in exempt]

if untagged:
    for i,n in untagged:
        bad(f"{i} (line {n}) has no source tag — R10: cut it or mark [NEEDS CLARIFICATION], never assert it")
else:
    ok("every requirement and criterion carries a source tag")
for i,n in invalid:
    bad(f"{i} (line {n}) has a tag that is not a valid source "
        f"(Settled Q<n> / Grounding fact <n> / Strategy (chosen) / Principle: <file> / ADR-<id> / a ## Reads file)")

# ---- identifiers unique, and not renumbered ------------------------------
seen={}
for i,_,_,n in items:
    seen.setdefault(i,[]).append(n)
dup={k:v for k,v in seen.items() if len(v)>1}
if not dup: ok("identifiers unique")
else:
    for k,v in dup.items(): bad(f"{k} defined {len(v)}x (lines {v})")

if prev:
    old=dict(re.findall(r'^\s*(?:[-*+]\s+)?\*{0,2}((?:FR|SC)-\d+[a-z]?)\*{0,2}\s*[:—–-]?\s+(.{0,60})',
                        prev, re.M))
    new=dict((i,t[:60]) for i,t,_,_ in items)
    moved=[i for i in old if i in new and old[i].strip()[:40] != new[i].strip()[:40]
           and 'withdrawn' not in new[i].lower()]
    dropped=[i for i in old if i not in new]
    if moved:   note(f"text changed under existing identifiers ({', '.join(moved[:5])}) — confirm this is an edit, not a renumber")
    if dropped: bad(f"identifiers vanished rather than being marked withdrawn: {', '.join(dropped[:5])}")
    if not moved and not dropped: ok("identifiers stable against the previous draft")

# ---- every FR has an acceptance scenario ---------------------------------
if not scen_spans:
    bad("no ## Acceptance scenarios section")
else:
    body='\n'.join('\n'.join(lines[a:b+1]) for a,b in scen_spans)
    nocov=[i for i,_,_,_ in frs if i not in exempt and i not in body]
    ok("every requirement has an acceptance scenario") if not nocov \
        else bad(f"requirements with no acceptance scenario: {', '.join(nocov)}")
    if 'Given' not in body or 'hen' not in body:
        note("acceptance scenarios do not read as Given/When/Then")

# ---- success criteria name a number --------------------------------------
nonum=[i for i,t,_,_ in scs if not re.search(r'\d', t)]
if not nonum:
    ok("every success criterion names a number")
else:
    note(f"success criteria naming no number: {', '.join(nonum)} — fine only if each is a "
         f"binary/existence check; otherwise it fails the measurability rule")

# ---- unquantified adjectives outside quoted goals ------------------------
ADJ=r'\b(fast|quick|quickly|smooth|smoothly|robust|scalable|intuitive|seamless|' \
    r'graceful|gracefully|responsive|efficient|reliable|simple|easy|promptly|reasonable)\b'
hits=[]
for i,t,_,n in items:
    stripped=re.sub(r'"[^"]*"','',t)
    for m in re.finditer(ADJ, stripped, re.I): hits.append(f"{i}:'{m.group(1)}'")
ok("no unquantified adjectives in requirements") if not hits \
    else bad(f"unquantified adjective(s): {', '.join(hits[:8])}")

# ---- clarification markers are well formed -------------------------------
bare=len(re.findall(r'\[NEEDS CLARIFICATION\]', spec))
if bare: bad(f"{bare} bare [NEEDS CLARIFICATION] marker(s) with no reason — say what was deferred and why")
n_ok=len(re.findall(r'\[NEEDS CLARIFICATION:', spec))
if n_ok: ok(f"{n_ok} clarification marker(s), each with a reason")

# ---- P1 is a shippable slice ---------------------------------------------
if re.search(r'^\s*(?:[-*+]\s+)?\*{0,2}P1\b', spec, re.M):
    ok("P1/P2/P3 stories present")
else:
    note("no P1 story found — priorities come from the design record's [P1] tags")

print()
if fail==0: print(f"SPEC OK{f' ({warn} warning(s))' if warn else ''}"); sys.exit(0)
print(f"{fail} PROBLEM(S) — fix before writing"); sys.exit(1)
PY
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
