#!/usr/bin/env bash
# ABOUTME: Validates a drafted feature spec — source tags resolved against the design record, identifier
# ABOUTME: stability, acceptance coverage and unquantified adjectives. Enforces R10 deterministically, before the critic.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: check-spec.sh <path-to-spec.md> --tree <path-to-tree.md> [options]

  --closed-world  Check only what the document ASSERTS, never what it OMITS.
                  A draft mid-write is legitimately incomplete: sections stubbed,
                  scenarios not yet written. Open-world checks fail on every
                  honest intermediate state, which teaches the writer to evade
                  the checker rather than satisfy it. Closed-world checks are
                  true at every stage — a fabricated citation is wrong on write
                  three of nine exactly as it is wrong at the end.
                  Used by the PostToolUse hook. The full check runs at the gate.

  --tree <path>     The design record every source tag must resolve against.
                    Required: a tag that cannot be resolved is not a checked tag,
                    and a check that examined nothing must not report a pass.
  --prev <path>     The spec being amended, to catch a silent renumber.
  --allow-reword    Accept text changed under an existing identifier. Without it
                    a reword is a failure, because it is indistinguishable from
                    a renumber for any reader who was not present.
USAGE
}

SPEC=""; TREE=""; PREV=""; ALLOW_REWORD=0; CLOSED=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --tree) [ $# -ge 2 ] || { echo "FAIL  --tree needs a path"; exit 2; }; TREE="$2"; shift 2 ;;
    --prev) [ $# -ge 2 ] || { echo "FAIL  --prev needs a path"; exit 2; }; PREV="$2"; shift 2 ;;
    --allow-reword) ALLOW_REWORD=1; shift ;;
    --closed-world) CLOSED=1; shift ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *)
      [ -z "$SPEC" ] || { echo "FAIL  unexpected extra argument: $1"; usage; exit 2; }
      SPEC="$1"; shift ;;
  esac
done

[ -z "$SPEC" ] && { usage; exit 2; }
[ -f "$SPEC" ] || { echo "FAIL  no such file: $SPEC"; exit 2; }

if [ -z "$TREE" ]; then
  echo "FAIL  --tree is required"
  echo "      Source tags are the whole of R10. Without the design record this"
  echo "      script can only confirm a tag is shaped like a tag, which is the"
  echo "      check a fabricated citation passes."
  exit 2
fi
[ -f "$TREE" ] || { echo "FAIL  design record not found: $TREE"; exit 2; }

# A previous spec that was asked for but cannot be read must not silently disable the
# renumber check — that check is the whole point of passing it on an amendment.
if [ -n "$PREV" ] && [ ! -f "$PREV" ]; then
  echo "FAIL  previous spec not found: $PREV"
  echo "      pass the real path to the existing spec.md, or omit --prev entirely"
  exit 2
fi
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found — check-spec.sh cannot run"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

out=$(PYTHONPATH="$HERE/lib" python3 - "$SPEC" "$TREE" "$PREV" "$ALLOW_REWORD" "$CLOSED" <<'PY'
import re,sys,os
from record import Record, Spec, tag_sources, resolve_tag, DEF_HEADS, SCEN_HEADS

spec=Spec.load(sys.argv[1])
rec=Record.load(sys.argv[2])
prev=open(sys.argv[3]).read() if sys.argv[3] and os.path.isfile(sys.argv[3]) else None
allow_reword=sys.argv[4]=='1'
# Closed-world: assert only about content that is present. Never about absence.
closed=sys.argv[5]=='1'
def skip_if_closed(label):
    if closed:
        print(f"skip  {label} (open-world — not checked on a partial draft)")
        return True
    return False
fail=warn=0
def bad(m,expected=None):
    global fail; print(f"FAIL  {m}"); fail+=1
    if expected:
        for line in expected.splitlines(): print(f"      expected: {line}")
def note(m):
    global warn; print(f"WARN  {m}"); warn+=1
def ok(m): print(f"ok    {m}")

TAG_SHAPE=("FR-001  The importer resumes from the last checkpoint on restart.\n"
           "        ← Settled Q1\n"
           "valid sources: Settled Q<n> | Grounding fact <n> | Strategy (chosen) | "
           "Principle: <file> | ADR-<id> | a ## Reads file\n"
           "a tag may name several, comma separated: ← Settled Q2 (r1), Grounding fact 7")

def_spans  = spec.spans(DEF_HEADS)
scen_spans = spec.spans(SCEN_HEADS)

if not def_spans and closed:
    print("ok    nothing asserted yet — no requirement sections to check")
    print(); print("SPEC OK (closed-world)"); sys.exit(0)
if not def_spans:
    bad("no '## Requirements' or '## Success criteria' section — is this a drafted spec?",
        "## Requirements\nFR-001  <one testable statement of behaviour>\n        ← Settled Q1")
    print(); print("1 PROBLEM(S) — fix before writing"); sys.exit(1)

items=spec.items()                 # (id, text, tagline or None, lineno)

# ---- nothing in a definition section names an id the parser could not read --
orphans=spec.unparsed_identifiers()
if orphans:
    for n,txt in orphans:
        bad(f"line {n} names an identifier the checker could not parse as a definition: '{txt}'")
    bad("unparsed identifiers mean the checks below examined less than the whole spec",
        "FR-001  <statement>   — each on its own line")
else:
    ok("every identifier in the requirement sections parsed")

if not items and closed:
    print("ok    no identifiers asserted yet")
    print(); print("SPEC OK (closed-world)"); sys.exit(0)
if not items:
    bad("requirement sections contain no FR-NNN or SC-NNN identifiers", TAG_SHAPE)
    print(); print(f"{fail} PROBLEM(S) — fix before writing"); sys.exit(1)

frs=[x for x in items if x[0].startswith('FR')]
scs=[x for x in items if x[0].startswith('SC')]
ok(f"found {len(frs)} requirements, {len(scs)} success criteria")
if not frs and not skip_if_closed("requirements present"):
    bad("no FR-NNN requirements found — a spec with no requirements is not a spec")

# ---- R10: every statement carries a source tag ---------------------------
withdrawn={i for i,t,_,_ in items if 'withdrawn' in t.lower()}
marked  ={i for i,t,_,_ in items if 'NEEDS CLARIFICATION' in t}
exempt=withdrawn|marked

untagged=[(i,n) for i,t,tag,n in items if not tag and i not in exempt]

if untagged and skip_if_closed("every item carries a source tag"):
    pass
elif untagged:
    for i,n in untagged:
        bad(f"{i} (line {n}) has no source tag — R10: cut it or mark [NEEDS CLARIFICATION], never assert it",
            TAG_SHAPE)
else:
    ok("every requirement and criterion carries a source tag")

# ---- R10, the half that was missing: does EVERY source in the tag resolve? --
# Shape-checking a citation is the check a fabricated citation passes, and
# resolving only the first source in a tag is the check the second one passes.
# A tag naming three sources is three citations, and all three are looked up.
unresolved=[]
n_sources=0
for i,t,tag,n in items:
    if not tag: continue
    srcs=tag_sources(tag)
    if not srcs:
        bad(f"{i} (line {n}) has a tag the parser could not read as any source", TAG_SHAPE)
        continue
    n_sources+=len(srcs)
    for src in srcs:
        why=resolve_tag(src, rec)
        if why:
            unresolved.append((i,n,src,why))

if unresolved:
    for i,n,src,why in unresolved:
        bad(f"{i} (line {n}) cites '{src}' but {why} — a source tag that does not resolve is a fabricated citation")
    bad("R10 is not satisfied by a tag that looks right",
        "every source named in every tag must exist in the design record")
else:
    ok(f"all {n_sources} source(s) across {len(items)} tag(s) resolve to the design record "
       f"({len(rec.settled_ids())} settled, {len(rec.grounding_facts())} grounding facts, "
       f"{len(rec.adr_ids())} ADRs)")

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
    # A reword under a stable identifier is indistinguishable from a renumber to
    # anyone who was not in the room. The rubric calls a moved identifier blocking;
    # a warning inside a fix-until-clean loop is a finding nobody reads.
    if moved:
        if allow_reword:
            note(f"text changed under existing identifiers ({', '.join(moved[:5])}) — accepted via --allow-reword")
        else:
            bad(f"text changed under existing identifiers: {', '.join(moved[:5])}",
                "keep the wording, or re-run with --allow-reword to record the edit as deliberate")
    if dropped: bad(f"identifiers vanished rather than being marked withdrawn: {', '.join(dropped[:5])}",
                    "FR-007  <original statement> (withdrawn)")
    if not moved and not dropped: ok("identifiers stable against the previous draft")

# ---- every FR has an acceptance scenario ---------------------------------
if skip_if_closed("acceptance scenario per requirement"):
    pass
elif not scen_spans:
    bad("no ## Acceptance scenarios section",
        "## Acceptance scenarios\nFR-001  Given <state>, when <action>, then <observable result>.")
else:
    body=spec.scenarios_body()
    nocov=[i for i,_,_,_ in frs if i not in exempt and i not in body]
    ok("every requirement has an acceptance scenario") if not nocov \
        else bad(f"requirements with no acceptance scenario: {', '.join(nocov)}",
                 "FR-00N  Given <state>, when <action>, then <observable result>.")
    if 'Given' not in body or 'hen' not in body:
        note("acceptance scenarios do not read as Given/When/Then")

# ---- success criteria name a number --------------------------------------
# Digits, never number-words. A criterion is checked by comparing against a
# value, and a reader who has to parse English to find that value will
# eventually parse it differently.
NUMBER_WORD=re.compile(r'\b(zero|one|two|three|four|five|six|seven|eight|nine|ten|'
                       r'eleven|twelve|once|twice)\b', re.I)
if not closed:
    nonum=[i for i,t,_,_ in scs if not re.search(r'\d', t)]
    worded=[i for i,t,_,_ in scs if not re.search(r'\d', t) and NUMBER_WORD.search(t)]
    if not nonum:
        ok("every success criterion names a number")
    else:
        note(f"success criteria naming no number: {', '.join(nonum)} — fine only if each is a "
             f"binary/existence check; otherwise it fails the measurability rule")
    if worded:
        note(f"{', '.join(worded)} spell a number as a word — criteria are written with "
             f"digits, so the value can be read without parsing English")

# ---- unquantified adjectives outside quoted goals ------------------------
ADJ=r'\b(fast|quick|quickly|smooth|smoothly|robust|scalable|intuitive|seamless|' \
    r'graceful|gracefully|responsive|efficient|reliable|simple|easy|promptly|reasonable)\b'
hits=[]
for i,t,_,n in items:
    stripped=re.sub(r'"[^"]*"','',t)
    for m in re.finditer(ADJ, stripped, re.I): hits.append(f"{i}:'{m.group(1)}'")
ok("no unquantified adjectives in requirements") if not hits \
    else bad(f"unquantified adjective(s): {', '.join(hits[:8])}",
             "the number the adjective stands in for — 'reports progress at least once every 2s'")

# ---- clarification markers are well formed -------------------------------
bare=len(re.findall(r'\[NEEDS CLARIFICATION\]', spec.text))
if bare: bad(f"{bare} bare [NEEDS CLARIFICATION] marker(s) with no reason",
             "[NEEDS CLARIFICATION: per-source overrides — low impact, deferred to post-launch]")
n_ok=len(spec.open_markers())
if n_ok: ok(f"{n_ok} clarification marker(s), each with a reason")

# ---- P1 is a shippable slice ---------------------------------------------
if closed:
    pass
elif spec.stories():
    ok("P1/P2/P3 stories present")
else:
    note("no P1 story found — priorities come from the design record's [P1] tags")

print()
mode=' (closed-world)' if closed else ''
if fail==0: print(f"SPEC OK{mode}{f' ({warn} warning(s))' if warn else ''}"); sys.exit(0)
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
