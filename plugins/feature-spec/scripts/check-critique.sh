#!/usr/bin/env bash
# ABOUTME: Validates a critic's reply — its shape, that every quote is text the critic was shown, and that
# ABOUTME: a second pass accounts for every finding the first raised, so none vanishes and ships as resolved.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: check-critique.sh <pass1> --single [--packet <packet>]
       check-critique.sh <pass1> <pass2> [--packet <packet>]

  Asserts the critic's reply is well formed: a verdict that agrees with its
  findings, a QUOTE and a FIX on every blocking finding, and, when nothing is
  blocking, a list of what was checked that names what it is about.

  With two passes, also asserts the second reports a disposition for every
  blocking id the first raised:  - B1 fixed   or   - B2 not fixed — <why>.
  A new finding (B4, B5…) is allowed and reported.

  --single         Validate one pass only. Use after the first critic call,
                   before deciding to re-run.
  --packet <path>  The packet the critic was given. Every QUOTE has to be text
                   it contains: a finding about words that are not there is a
                   finding about nothing. With two passes, the second pass is
                   the one checked, against the packet it was given.

Exit 0 clean · 1 findings · 2 could not run.
USAGE
}

P1=""; P2=""; SINGLE=0; PACKET=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --single) SINGLE=1; shift ;;
    --packet) [ $# -ge 2 ] || { echo "FAIL  --packet needs a path"; exit 2; }; PACKET="$2"; shift 2 ;;
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
# A packet that was asked for and cannot be read must not quietly turn the
# quote check off.
if [ -n "$PACKET" ] && [ ! -f "$PACKET" ]; then
  echo "FAIL  packet not found: $PACKET"
  exit 2
fi
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found"; exit 2; }

python3 - "$P1" "${P2:-}" "$SINGLE" "$PACKET" <<'PY'
import re, sys

p1 = open(sys.argv[1]).read()
single = sys.argv[3] == '1'
p2 = open(sys.argv[2]).read() if not single else None
packet = open(sys.argv[4]).read() if sys.argv[4] else None

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
         "BLIND SPOT: <what this pass could not assess, or none>")

# A finding id is a label, and its severity is the section it sits under: lenses
# run in parallel need distinct prefixes, and a parser keyed on `B` would read
# their blocking findings as zero.
ID = r'[A-Z]{1,3}\d+[a-z]?'
FINDING = re.compile(rf'^\s*-\s*\*{{0,2}}({ID})\b', re.M)
# A disposition follows its id directly. "B1 fixed. Unlike B2, nothing new" says
# nothing about B2, and "could not be verified as fixed" is not "fixed". The
# unresolved phrasings come first because "not fixed" contains "fixed".
OPEN = r'not fixed|unfixed|not resolved|unresolved|still open|partially fixed|partly fixed'
CLOSED = r'fixed|resolved|superseded|withdrawn'
DISPO_LINE = re.compile(rf'^\s*-\s*\*{{0,2}}({ID})\*{{0,2}}\s*[—–:-]?\s*({OPEN}|{CLOSED})\b',
                        re.M | re.I)
# An all-caps line is a section header in the output skeleton.
HEADER = re.compile(r'^(?:[A-Z][A-Z ]*[A-Z]|[A-Z]+)[ \t]*$', re.M)
# The skeleton's own slots. A reply that still carries one was not filled in.
PLACEHOLDER = re.compile(r'<(?:finding|verbatim[^>]*|one sentence[^>]*|what this pass[^>]*|'
                         r'the smallest edit[^>]*|required when[^>]*|claim needing[^>]*)>'
                         r'|^VERDICT:[^\n]*\|', re.M)


def section_body(text, name):
    """Text under an all-caps heading, up to the next one. None if absent."""
    m = re.search(rf'^{name}[ \t]*$', text, re.M)
    if not m:
        return None
    rest = text[m.end():]
    nxt = HEADER.search(rest)
    return rest[:nxt.start()] if nxt else rest


def findings_in(text, name):
    return FINDING.findall(section_body(text, name) or '')


def segment(text, fid):
    """One finding's lines: from its bullet to the next bullet or heading."""
    m = re.search(rf'^\s*-\s*\*{{0,2}}{fid}\b(.*?)'
                  rf'(?=^\s*-\s*\*{{0,2}}{ID}\b|^(?:[A-Z][A-Z ]*[A-Z]|[A-Z]+)[ \t]*$|\Z)',
                  text, re.M | re.S)
    return m.group(1) if m else ''


def squash(t):
    """Letters and digits only. A quote survives re-wrapping, escaped quote
    marks and markdown decoration; invented words do not."""
    return re.sub(r'[^0-9a-z]+', '', t.casefold())


def unsupported(quote, hay):
    """Fragments of `quote` that `hay` does not contain. An ellipsis splits a
    quote, and a fragment too short to identify anything is not judged."""
    frags = [squash(f) for f in re.split(r'…|\.\.\.', quote)]
    return [f for f in frags if len(f) >= 12 and f not in hay]


def parse(text, label):
    v = re.search(r'^VERDICT:\s*(ship|fix-first)\b', text, re.M | re.I)
    if not v:
        bad(f"{label}: no VERDICT line — 'it depends' is useless from a critic", SHAPE)
    if not re.search(r'^CONFIDENCE:\s*(high|moderate|low)\b', text, re.M | re.I):
        bad(f"{label}: no calibrated CONFIDENCE line", SHAPE)
    if not re.search(r'^BLIND SPOT:[ \t]*\S', text, re.M | re.I):
        bad(f"{label}: no BLIND SPOT line — write 'none' when every check ran on text in the packet", SHAPE)
    if PLACEHOLDER.search(text):
        bad(f"{label}: the reply still carries the output template's placeholders",
            "each slot filled in, or its section left out")
    blocking = findings_in(text, 'BLOCKING')
    advisory = findings_in(text, 'ADVISORY')
    # Findings outside both sections cannot be classified, and a finding this
    # script cannot see is a finding that ships as resolved.
    if not blocking and not advisory:
        accounted = (set(findings_in(text, 'CHECKED AND SOUND'))
                     | set(findings_in(text, 'COULD NOT VERIFY'))
                     | set(findings_in(text, 'RECONCILIATION'))
                     | {m.group(1) for m in DISPO_LINE.finditer(text)})
        loose = [i for i in FINDING.findall(text) if i not in accounted]
        if loose:
            bad(f"{label}: {len(loose)} identified finding(s) ({', '.join(loose[:5])}) sit "
                f"under no BLOCKING or ADVISORY heading — severity is the section, not the id",
                "BLOCKING\n- B1 [completeness] FR-004 — <finding>")
    # Every blocking finding says what it is about and what would clear it:
    # there is one re-run, and a finding without either wastes it.
    lacking = 0
    for bid in blocking:
        body = segment(text, bid)
        if not re.search(r'FIX:[ \t]*\S', body):
            lacking += 1
            bad(f"{label}: {bid} has no FIX: — a finding that does not say what would "
                f"clear it wastes the one allowed re-run",
                "FIX: <the smallest edit that would clear this>")
        if not re.search(r'QUOTE:[ \t]*["“]?[ \t]*[^\s"”]', body):
            lacking += 1
            bad(f"{label}: {bid} carries no QUOTE: — a paraphrase is a finding nobody can check",
                'QUOTE: "<verbatim from the packet>"')
    if blocking and not lacking:
        ok(f"{label}: all {len(blocking)} blocking findings carry QUOTE and FIX")
    return (v.group(1).lower() if v else None), blocking, advisory


def check_quotes(text, label, blocking, advisory):
    """Every quote is text the critic was shown."""
    if packet is None:
        return
    hay = squash(packet)
    n = 0
    for fid in blocking + advisory:
        for q in re.findall(r'QUOTE:[ \t]*(.+)$', segment(text, fid), re.M):
            n += 1
            if unsupported(q, hay):
                bad(f"{label}: {fid} quotes text the packet does not contain: {q.strip()[:70]} — "
                    f"do not edit the spec for a finding about words that are not there",
                    "the words as they stand in the packet")
    # CHECKED AND SOUND is not compared. Nothing is edited because of it, and a
    # quoted span there is as often a label or a line of code the critic opened
    # as a quotation from the packet.
    if n:
        ok(f"{label}: {n} quote(s) compared against the packet")


verdict1, b1, a1 = parse(p1, "pass 1")
ok(f"pass 1: verdict {verdict1 or '?'}, {len(b1)} blocking, {len(a1)} advisory")

if verdict1 == 'ship' and b1:
    bad(f"pass 1: VERDICT is ship with {len(b1)} blocking finding(s) — a blocking finding means fix-first",
        "VERDICT: fix-first")
if verdict1 == 'fix-first' and not b1:
    bad("pass 1: VERDICT is fix-first with nothing under BLOCKING — name what has to be fixed, or ship",
        "BLOCKING\n- B1 [completeness] FR-004 — <finding>")

# A critic that returns nothing is the failure mode. "Looks good" is two words
# anyone can write; an item that names what it checked is not.
if not b1:
    sound = section_body(p1, 'CHECKED AND SOUND')
    SOUND_SHAPE = ('CHECKED AND SOUND\n'
                   '- FR-002 "at most 5 times" says what Settled Q2 says, "at most 5 attempts"\n'
                   '- SC-001 names its number, 2 seconds')
    if sound is None:
        bad("pass 1: no blocking findings and no CHECKED AND SOUND section — "
            "'looks good' is not a valid return", SOUND_SHAPE)
    else:
        items = re.findall(r'^\s*-\s+(\S.*)$', sound, re.M)
        cited = [i for i in items
                 if re.search(r'["“][^"”]{8,}["”]', i)
                 or re.search(r'\b(?:(?:FR|SC)-\d+|T\d{2,}|[MQ]\d+)\b', i)]
        if len(cited) < 2:
            bad(f"pass 1: CHECKED AND SOUND has {len(cited)} item(s) that name what was checked — "
                f"each item quotes the text or names the identifier it is about", SOUND_SHAPE)
        else:
            ok(f"pass 1: anti-rubber-stamp satisfied ({len(cited)} items checked and sound)")

if single:
    check_quotes(p1, "pass 1", b1, a1)
    print()
    if fail == 0:
        print(f"CRITIQUE OK{f' ({warn} warning(s))' if warn else ''}")
        if b1:
            print(f"  fix-first with {len(b1)} blocking — re-run once, then write regardless (R12)")
        sys.exit(0)
    print(f"{fail} PROBLEM(S) in the critic's output"); sys.exit(1)

verdict2, b2, a2 = parse(p2, "pass 2")
ok(f"pass 2: verdict {verdict2 or '?'}, {len(b2)} blocking, {len(a2)} advisory")
check_quotes(p2, "pass 2", b2, a2)

# The reconciliation. A finding that vanishes between passes ships as resolved.
dispo = {m.group(1): ('open' if re.fullmatch(OPEN, m.group(2), re.I) else 'closed')
         for m in DISPO_LINE.finditer(p2)}
missing = [b for b in b1 if b not in dispo and b not in b2]
if missing:
    bad(f"pass 2 does not account for {', '.join(missing)} from pass 1 — "
        f"a finding that vanishes between passes ships as resolved",
        "RECONCILIATION\n- B1 fixed\n- B2 not fixed — <why>")
else:
    ok(f"pass 2 accounts for all {len(b1)} pass-1 blocking finding(s)")

new = [b for b in b2 if b not in b1]
if new:
    print(f"      new in pass 2: {', '.join(new)}")
reused = [b for b in new if b in a1]
if reused:
    bad(f"finding id(s) reused across severities: {', '.join(reused)} — ids are never reused")

# Still open: said to be, or listed under BLOCKING again whatever its line says.
unresolved = [b for b in b1 if dispo.get(b) == 'open' or b in b2] + new
if verdict2 == 'ship' and unresolved:
    bad(f"pass 2: VERDICT is ship with {len(unresolved)} finding(s) still open "
        f"({', '.join(unresolved)}) — an open blocking finding means fix-first",
        "VERDICT: fix-first")
if verdict2 == 'fix-first' and not unresolved:
    bad("pass 2: VERDICT is fix-first with every finding fixed and nothing new — name what is open, or ship",
        "- B2 not fixed — <why>")

print()
if fail == 0:
    print(f"CRITIQUE OK{f' ({warn} warning(s))' if warn else ''}")
    if unresolved:
        print(f"  {len(unresolved)} finding(s) ship unresolved: {', '.join(unresolved)}")
        print("  Write anyway (R12); these stay in the critique files and go in the report.")
    sys.exit(0)
print(f"{fail} PROBLEM(S) in the critic reconciliation"); sys.exit(1)
PY
