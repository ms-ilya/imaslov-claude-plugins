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
                    a renumber for any reader who was not present. A statement
                    that moved to another identifier fails either way.
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
from record import (Record, Spec, tag_sources, resolve_tag, DEF_HEADS, SCEN_HEADS,
                    SCOPE_HEADS, CONSTRAINT_HEADS, WITHDRAWN, FACT_VERDICT)

spec=Spec.load(sys.argv[1])
rec=Record.load(sys.argv[2])
prev=Spec.load(sys.argv[3]) if sys.argv[3] and os.path.isfile(sys.argv[3]) else None
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
def finish():
    print()
    mode=' (closed-world)' if closed else ''
    if fail==0:
        print(f"SPEC OK{mode}{f' ({warn} warning(s))' if warn else ''}"); sys.exit(0)
    print(f"{fail} PROBLEM(S) — fix before writing"); sys.exit(1)

TAG_SHAPE=("FR-001  The importer resumes from the last checkpoint on restart.\n"
           "        ← Settled Q1\n"
           "valid sources: Settled Q<n> | Grounding fact <n> | Strategy (chosen) | "
           "Principle: <file> | ADR-<id>\n"
           "a tag may name several, comma separated: ← Settled Q2 (r1), Grounding fact 7")
SECTIONS=("## User stories | Requirements | Success criteria | Acceptance scenarios | "
          "Out of scope | Implementation constraints | Chosen approach | "
          "Principle deviations | Clarifications | Open questions")

# ---- the sections are the template's, each once --------------------------
# A statement under a heading nobody defined is read by no check below and is
# left out of the critic's packet, so it would ship unexamined.
for head,n in spec.unknown_sections():
    bad(f"line {n}: '{head}' is not a section of the spec template — what sits under it is checked by nothing",
        SECTIONS)
for name in spec.repeated_sections():
    bad(f"the spec has more than one '{name}' section — only the first is read",
        "one section per heading")

def_spans  = spec.spans(DEF_HEADS)
scen_spans = spec.spans(SCEN_HEADS)

if not def_spans and closed:
    if fail==0: print("ok    nothing asserted yet — no requirement sections to check")
    finish()
if not def_spans:
    bad("no '## Requirements' or '## Success criteria' section — is this a drafted spec?",
        "## Requirements\nFR-001  <one testable statement of behaviour>\n        ← Settled Q1")
    finish()

items=spec.items()                 # (id, text, tagline or None, lineno)

# ---- every line of a requirement section belongs to an identified item ----
# A bullet with no FR/SC number, or a line after an item's tag, asserts
# something no tag covers.
strays=spec.stray_lines()
if strays:
    for n,txt in strays:
        bad(f"line {n} in a requirement section belongs to no identifier: '{txt}'",
            "FR-00N  <statement>, its ← tag on the line below; a longer statement continues on indented lines")
else:
    ok("every line in the requirement sections belongs to an identified statement")

if not items and closed:
    if fail==0: print("ok    no identifiers asserted yet")
    finish()
if not items:
    bad("requirement sections contain no FR-NNN or SC-NNN identifiers", TAG_SHAPE)
    finish()

frs=[x for x in items if x[0].startswith('FR')]
scs=[x for x in items if x[0].startswith('SC')]
ok(f"found {len(frs)} requirements, {len(scs)} success criteria")
if not frs and not skip_if_closed("requirements present"):
    bad("no FR-NNN requirements found — a spec with no requirements is not a spec")

# ---- R10: every statement carries a source tag ---------------------------
withdrawn={i for i,t,_,_ in items if WITHDRAWN.search(t)}
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
facts=rec.grounding_facts()
def unusable(src):
    """Why this source cannot carry a statement, or None."""
    why=resolve_tag(src, rec)
    if why: return why
    f=re.match(r'Grounding fact\s+(\d+)$', src)
    v=FACT_VERDICT.search(facts.get(f.group(1),'')) if f else None
    if v and v.group(1).lower()=='unverifiable':
        return ("the record grades that claim unverifiable, so it is not a fact: "
                "what depends on it is an open question")
    return None

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
        why=unusable(src)
        if why:
            unresolved.append((i,n,src,why))

if unresolved:
    for i,n,src,why in unresolved:
        bad(f"{i} (line {n}) cites '{src}' but {why} — a source tag that does not resolve is a fabricated citation")
    bad("R10 is not satisfied by a tag that looks right",
        "every source named in every tag must exist in the design record")
else:
    ok(f"all {n_sources} source(s) across {len(items)} tag(s) resolve to the design record "
       f"({len(rec.settled_ids())} settled, {len(facts)} grounding facts, "
       f"{len(rec.adr_ids())} ADRs)")

# ---- tags outside the requirement sections resolve too ------------------
# An out-of-scope line and an implementation constraint cite the record as well.
# Leaving those tags unchecked would make them the one place in the spec where
# a fabricated citation is free.
item_tag_lines=spec.item_tag_lines()
other_bad=[]; n_other=0
for ln,line in spec.all_tags():
    if ln in item_tag_lines: continue
    for src in tag_sources(line):
        n_other+=1
        why=unusable(src)
        if why: other_bad.append((ln,src,why))
if other_bad:
    for ln,src,why in other_bad:
        bad(f"line {ln} cites '{src}' but {why} — a source tag that does not resolve is a fabricated citation")
elif n_other:
    ok(f"all {n_other} source(s) cited outside the requirement sections resolve")

# ---- a scope line and a constraint are decisions, so each carries its tag --
loose=[(n,label) for names,label in ((SCOPE_HEADS,'## Out of scope'),
                                     (CONSTRAINT_HEADS,'## Implementation constraints'))
       for n,text in spec.bullets(names) if '←' not in text]
if loose:
    for n,label in loose:
        bad(f"line {n} under {label} has no source tag — it states a decision, so it names the one it came from",
            "- <the line> ← Settled Q<n>")
elif spec.bullets(SCOPE_HEADS) or spec.bullets(CONSTRAINT_HEADS):
    ok("every out-of-scope line and implementation constraint carries a source tag")

# ---- identifiers unique, and not renumbered ------------------------------
seen={}
for i,_,_,n in items:
    seen.setdefault(i,[]).append(n)
dup={k:v for k,v in seen.items() if len(v)>1}
if not dup: ok("identifiers unique")
else:
    for k,v in dup.items(): bad(f"{k} defined {len(v)}x (lines {v})")

if prev:
    def norm(t): return re.sub(r'\s+',' ',t).strip()
    old={i:norm(t) for i,t,_,_ in prev.items()}
    new={i:norm(t) for i,t,_,_ in items}
    owner={}
    for i,t in old.items(): owner.setdefault(t,i)
    changed=[i for i in old if i in new and old[i]!=new[i] and not WITHDRAWN.search(new[i])]
    # A statement that turns up under another identifier is a renumber, and no
    # flag excuses it: every reference to the old number now points elsewhere.
    renumbered=[(i,owner[new[i]]) for i in changed if owner.get(new[i],i)!=i]
    reworded=[i for i in changed if i not in {a for a,_ in renumbered}]
    dropped=[i for i in old if i not in new]
    for i,was in renumbered:
        bad(f"{i} now carries the statement {was} had — identifiers were renumbered",
            "an identifier keeps its statement; a new statement takes the next free number")
    # A reword under a stable identifier is indistinguishable from a renumber to
    # anyone who was not in the room, so it fails until it is acknowledged.
    if reworded:
        if allow_reword:
            note(f"text changed under existing identifiers ({', '.join(reworded[:5])}) — accepted via --allow-reword")
        else:
            bad(f"text changed under existing identifiers: {', '.join(reworded[:5])}",
                "keep the wording, or re-run with --allow-reword to record the edit as deliberate")
    if dropped: bad(f"identifiers vanished rather than being marked withdrawn: {', '.join(dropped[:5])}",
                    "FR-007  <original statement> (withdrawn)")
    if not changed and not dropped: ok("identifiers stable against the previous spec")

# ---- every FR has an acceptance scenario ---------------------------------
# A scenario is keyed by the identifier that opens its line. A requirement that
# is only mentioned in a sentence has not been given a scenario.
scen=spec.scenario_ids()
defined={i for i,_,_,_ in frs}
for i,n in scen:
    if i not in defined:
        bad(f"line {n}: a scenario is keyed to {i}, which the spec does not define")
if skip_if_closed("acceptance scenario per requirement"):
    pass
elif not scen_spans:
    bad("no ## Acceptance scenarios section",
        "## Acceptance scenarios\nFR-001  Given <state>, when <action>, then <observable result>.")
else:
    have={i for i,_ in scen}
    nocov=[i for i,_,_,_ in frs if i not in exempt and i not in have]
    ok("every requirement has an acceptance scenario") if not nocov \
        else bad(f"requirements with no acceptance scenario: {', '.join(nocov)}",
                 "FR-00N  Given <state>, when <action>, then <observable result>.")
    body=spec.scenarios_body()
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
# One deferred question is one marker. Every marker is counted here and carried
# into the plan as its own open question, so a question marked inline and again
# under ## Open questions reads downstream as two.
opens={}
for m in spec.open_markers():
    q=re.match(r'\s*(Q\d+)\b', m)
    if q: opens[q.group(1)]=opens.get(q.group(1),0)+1
# A tagged statement was decided; an inline marker says nobody decided it. Both
# on one line is how a deferred question ends up marked a second time, in words
# that match nothing under ## Open questions.
both=[(i,n) for i,t,tag,n in items if tag and 'NEEDS CLARIFICATION' in t]
for i,n in both:
    bad(f"{i} (line {n}) carries both a source tag and an inline marker — a decided statement that waits on a deferred question names the question id in words",
        "FR-007  <statement> (the value is open: see Q17)\n        ← Settled Q5")
# The id is what makes the rule above checkable, so a marker under
# ## Open questions that does not open with one is malformed, not merely terse.
oq=spec.section_text('open questions') or ''
oq_markers=re.findall(r'\[NEEDS CLARIFICATION:\s*(.*?)\]', oq, re.S)
anon=[m for m in oq_markers if not re.match(r'\s*Q\d+\b', m)]
if anon:
    bad(f"{len(anon)} marker(s) under ## Open questions name no question id: '{anon[0].strip()[:50]}'",
        "[NEEDS CLARIFICATION: Q12 — per-source overrides, deferred to post-launch]")
twice=sorted(k for k,v in opens.items() if v>1)
if twice:
    bad(f"{', '.join(twice)} marked [NEEDS CLARIFICATION] more than once — one deferred question is one marker",
        "the marker once, under ## Open questions; a requirement that depends on it names the question id in words")
# A marker and the record's ## Deferred list are the same set of questions. One
# the record never deferred is an open question nobody raised; one the record
# deferred and the spec does not carry has been quietly dropped.
deferred=[d['id'] for d in rec.deferred_entries()]
settled_ids=rec.settled_ids()
for q in sorted(opens, key=lambda k:int(k[1:])):
    if q not in deferred:
        bad(f"a marker names {q}, which the record does not defer"
            + (" — the record settled it" if q in settled_ids else ""),
            "a marker for each question under the record's ## Deferred, and for no other")
carried={m.group(1) for t in oq_markers for m in [re.match(r'\s*(Q\d+)\b', t)] if m}
missing=[q for q in deferred if q not in carried]
if missing and not skip_if_closed("every deferred question is carried as a marker"):
    bad(f"deferred in the record but not carried under ## Open questions: {', '.join(missing)}",
        "## Open questions\n- [NEEDS CLARIFICATION: Q12 — <what was deferred, and why>]")
elif deferred and not missing:
    ok(f"all {len(deferred)} deferred question(s) are carried as markers")

# ---- the clarifications index points at settled questions -----------------
ghosts=[m.group(1) for m in re.finditer(r'^\s*[-*+]\s+\*{0,2}(Q\d+)\b',
                                        spec.section_text('clarifications') or '', re.M)
        if m.group(1) not in settled_ids]
if ghosts:
    bad(f"## Clarifications lists {', '.join(ghosts)}, which the record never settled",
        "one line per ## Settled entry, copied from the record")

# ---- P1 is a shippable slice ---------------------------------------------
if closed:
    pass
elif spec.stories():
    ok("P1/P2/P3 stories present")
else:
    note("no P1 story found — priorities come from the design record's [P1] tags")

finish()
PY
)
status=$?

# 0 = clean, 1 = findings the checker reported. A crash also exits 1, with no
# result line, and a checker that did not reach a verdict must not read as a
# list of findings or as a pass.
if [ "$status" -gt 1 ] || ! printf '%s\n' "$out" | grep -qE '^(SPEC OK|[0-9]+ PROBLEM)'; then
  [ -n "$out" ] && echo "$out"
  echo "FAIL  checker did not reach a verdict (python3 exited $status)"
  exit 2
fi

echo "$out"
exit "$status"
