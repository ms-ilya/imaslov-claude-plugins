#!/usr/bin/env bash
# ABOUTME: Reconciles a critic's second pass against its first — asserts every pass-1 finding id is
# ABOUTME: accounted for, so a finding cannot quietly vanish between passes and ship as resolved.
#
# Exactly one re-run is allowed, and the rubric is right that the ids are
# load-bearing. But the reconciliation itself was prose about prose, with nothing
# checking that pass 2 mentioned every id pass 1 raised.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: check-critique.sh <pass1.txt> <pass2.txt>
       check-critique.sh <pass1.txt> --single

  Asserts the critic's output is well formed, and that the second pass reports a
  disposition for every blocking id the first pass raised: fixed, not fixed, or
  superseded. A new finding (B4, B5…) is allowed and reported.

  --single  Validate one pass only — shape, verdict, and the anti-rubber-stamp
            rule. Use after the first critic call, before deciding to re-run.

Exit 0 clean · 1 findings · 2 could not run.
USAGE
}

P1=""; P2=""; SINGLE=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --single) SINGLE=1; shift ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *) if [ -z "$P1" ]; then P1="$1"; elif [ -z "$P2" ]; then P2="$1";
       else echo "FAIL  unexpected extra argument: $1"; exit 2; fi; shift ;;
  esac
done

[ -z "$P1" ] && { usage; exit 2; }
[ -f "$P1" ] || { echo "FAIL  no such file: $P1"; exit 2; }
if [ "$SINGLE" -eq 0 ]; then
  [ -z "$P2" ] && { echo "FAIL  pass 2 not given — use --single to check one pass"; exit 2; }
  [ -f "$P2" ] || { echo "FAIL  no such file: $P2"; exit 2; }
fi
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found"; exit 2; }

python3 - "$P1" "${P2:-}" "$SINGLE" <<'PY'
import re, sys

p1 = open(sys.argv[1]).read()
single = sys.argv[3] == '1'
p2 = open(sys.argv[2]).read() if not single else None

fail = warn = 0
def bad(m, expected=None):
    global fail; print(f"FAIL  {m}"); fail += 1
    if expected:
        for l in expected.splitlines(): print(f"      expected: {l}")
def note(m):
    global warn; print(f"WARN  {m}"); warn += 1
def ok(m): print(f"ok    {m}")

SHAPE = ("VERDICT: ship | fix-first\n"
         "CONFIDENCE: high | moderate | low — <one sentence>\n"
         "BLIND SPOT: <what this pass could not assess>")

# A finding id is a label, and its severity is the section it sits under. The
# prefix was the signal before, which made the rubric and this parser mutually
# exclusive: three parallel lenses MUST use distinct prefixes or their ids
# collide, and every scheme that disambiguates them was invisible here. Two real
# blocking findings read as zero, and pass 2 then "accounted for all 0".
ID = r'[A-Z]{1,3}\d+[a-z]?'
DISPO_WORDS = (r'(fixed|not fixed|unfixed|resolved|unresolved|superseded|'
               r'withdrawn|still open|new)')
FINDING = re.compile(rf'^\s*-\s*\*{{0,2}}({ID})\b', re.M)
# `- B2 not fixed` is a disposition, not a finding, wherever it is written.
# Pass 2 is mostly such lines, and counting them as unclassified findings would
# report a problem in every well-formed second pass.
DISPO_LINE = re.compile(rf'^\s*-\s*\*{{0,2}}({ID})\b[^\n]*?\b{DISPO_WORDS}\b', re.M | re.I)
# An all-caps line is a section header in the rubric's output skeleton.
HEADER = re.compile(r'^([A-Z][A-Z ]*[A-Z]|[A-Z]+)\s*$', re.M)


def findings_in(text, section):
    """Ids bulleted under an all-caps SECTION heading, up to the next heading."""
    m = re.search(rf'^{section}[ \t]*$', text, re.M)
    if not m:
        return []
    rest = text[m.end():]
    nxt = HEADER.search(rest)
    return FINDING.findall(rest[:nxt.start()] if nxt else rest)


def parse(text, label):
    v = re.search(r'^VERDICT:\s*(ship|fix-first)\b', text, re.M | re.I)
    if not v:
        bad(f"{label}: no VERDICT line — 'it depends' is useless from a critic", SHAPE)
    if not re.search(r'^CONFIDENCE:\s*(high|moderate|low)\b', text, re.M | re.I):
        bad(f"{label}: no calibrated CONFIDENCE line", SHAPE)
    if not re.search(r'^BLIND SPOT:\s*\S', text, re.M | re.I):
        bad(f"{label}: no BLIND SPOT — honest scope beats false completeness", SHAPE)
    blocking = findings_in(text, 'BLOCKING')
    advisory = findings_in(text, 'ADVISORY')
    # Findings outside both sections cannot be classified, and a finding this
    # script cannot see is a finding that ships as resolved.
    if not blocking and not advisory:
        accounted = (set(findings_in(text, 'CHECKED AND SOUND'))
                     | set(findings_in(text, 'COULD NOT VERIFY'))
                     | {m.group(1) for m in DISPO_LINE.finditer(text)})
        loose = [i for i in FINDING.findall(text) if i not in accounted]
        if loose:
            bad(f"{label}: {len(loose)} identified finding(s) ({', '.join(loose[:5])}) sit "
                f"under no BLOCKING or ADVISORY heading — severity is the section, not the id",
                "BLOCKING\n- B1 [completeness] FR-004 — <finding>")
    return (v.group(1).lower() if v else None), blocking, advisory

verdict1, b1, a1 = parse(p1, "pass 1")
ok(f"pass 1: verdict {verdict1 or '?'}, {len(b1)} blocking, {len(a1)} advisory")

# Every blocking finding must say what would clear it: there is one attempt.
for bid in b1:
    seg = re.search(rf'^\s*-\s*\*{{0,2}}{bid}\b(.*?)(?=^\s*-\s*\*{{0,2}}{ID}\b|\Z)', p1, re.M | re.S)
    body = seg.group(1) if seg else ''
    if 'FIX:' not in body:
        bad(f"pass 1: {bid} has no FIX: — a finding that does not say what would "
            f"clear it wastes the one allowed re-run",
            "FIX: <the smallest edit that would clear this>")
    if 'QUOTE:' not in body:
        bad(f"pass 1: {bid} carries no QUOTE: — a paraphrase is a finding nobody can check",
            'QUOTE: "<verbatim from the draft>"')
if b1:
    ok(f"pass 1: all {len(b1)} blocking findings carry QUOTE and FIX")

# A critic that returns nothing is the failure mode.
if not b1:
    if not re.search(r'^CHECKED AND SOUND', p1, re.M | re.I):
        bad("pass 1: no blocking findings and no CHECKED AND SOUND section — "
            "'looks good' is not a valid return",
            "CHECKED AND SOUND\n- <what was specifically checked, citing verbatim>")
    else:
        sound = re.findall(r'^\s*-\s+\S.*$',
                           re.split(r'^CHECKED AND SOUND', p1, flags=re.M | re.I)[-1], re.M)
        if len(sound) < 2:
            note(f"pass 1: CHECKED AND SOUND lists {len(sound)} item(s) — thin for a clean pass")
        else:
            ok(f"pass 1: anti-rubber-stamp satisfied ({len(sound)} items checked and sound)")

if single:
    print()
    if fail == 0:
        print(f"CRITIQUE OK{f' ({warn} warning(s))' if warn else ''}")
        if verdict1 == 'fix-first' and b1:
            print(f"  fix-first with {len(b1)} blocking — re-run once, then write regardless (R12)")
        sys.exit(0)
    print(f"{fail} PROBLEM(S) in the critic's output"); sys.exit(1)

verdict2, b2, a2 = parse(p2, "pass 2")
ok(f"pass 2: verdict {verdict2 or '?'}, {len(b2)} blocking, {len(a2)} advisory")

# The reconciliation. A dropped finding currently ships as resolved.
DISPO = re.compile(rf'\b({ID})\b[^\n]*?\b{DISPO_WORDS}\b', re.I)
known = set(b1) | set(b2) | set(a1) | set(a2)
reported = {m.group(1): m.group(2).lower() for m in DISPO.finditer(p2)
            if m.group(1) in known}
missing = [b for b in b1 if b not in reported and b not in b2]
if missing:
    bad(f"pass 2 does not account for {', '.join(missing)} from pass 1 — "
        f"a finding that vanishes between passes ships as resolved",
        "B1 fixed · B2 not fixed · B3 new")
else:
    ok(f"pass 2 accounts for all {len(b1)} pass-1 blocking finding(s)")

new = [b for b in b2 if b not in b1]
if new:
    print(f"      new in pass 2: {', '.join(new)}")
reused = [b for b in new if b in a1]
if reused:
    bad(f"finding id(s) reused across severities: {', '.join(reused)} — ids are never reused")

unresolved = [b for b, d in reported.items() if d in ('not fixed', 'unfixed', 'unresolved', 'still open')]
print()
if fail == 0:
    print(f"CRITIQUE OK{f' ({warn} warning(s))' if warn else ''}")
    if unresolved or new:
        print(f"  {len(unresolved)+len(new)} finding(s) ship unresolved: "
              f"{', '.join(unresolved+new)}")
        print("  Write anyway (R12) and record these in critique.md.")
    sys.exit(0)
print(f"{fail} PROBLEM(S) in the critic reconciliation"); sys.exit(1)
PY
