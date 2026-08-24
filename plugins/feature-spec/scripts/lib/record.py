# ABOUTME: Shared parser for the design record and a drafted spec — the one place that knows both formats.
#
# Every tool that reads tree.md reads it through here. A second parser is a second
# thing to keep in step with tree-format.md, and the whole plugin is an argument
# against exactly that.

import os
import re

def is_external_path(p):
    """True for a path that names a file outside the repository tree.

    Phase 0 detects principles in `AGENTS.md`, `CLAUDE.md` and `.claude/rules/`,
    all of which a machine may keep only in `~`. Such an entry is legal in
    `## Reads`; it is just resolved differently."""
    return p.startswith('~') or os.path.isabs(p)


# --------------------------------------------------------------------- record


class Record:
    """A parsed `tree.md`. Every accessor returns something empty rather than
    raising, because a partially written record is the normal mid-interview
    state — `parses()` is what says whether the file is usable at all."""

    REQUIRED = ['Problem', 'Protocol', 'Reads', 'Coverage', 'Principles in force',
                'Grounding facts', 'Settled', 'Frontier', 'Blocked', 'Deferred', 'Sessions']

    def __init__(self, text, path=None):
        self.text = text
        self.path = path

    @classmethod
    def load(cls, path):
        with open(path) as fh:
            return cls(fh.read(), path)

    def section(self, name):
        m = re.search(rf'^## {re.escape(name)}[^\n]*$(.*?)(?=^## |\Z)',
                      self.text, re.M | re.S)
        return m.group(1) if m else None

    def missing_sections(self):
        return [s for s in self.REQUIRED if self.section(s) is None]

    def parses(self):
        return not self.missing_sections() and bool(self.problem())

    # -- content ---------------------------------------------------------
    def problem(self):
        body = self.section('Problem') or ''
        return ' '.join(l.strip() for l in body.splitlines() if l.strip())

    def settled(self):
        """[(qid, answer, why, round, priority)] in record order."""
        out = []
        body = self.section('Settled') or ''
        cur = None
        for line in body.splitlines():
            m = re.match(r'^\s*-\s+\*\*(Q\d+)([^*]*)\*\*\s*(?:→|->)\s*(.*)$', line)
            if m:
                if cur:
                    out.append(cur)
                title = m.group(2).strip()
                answer = m.group(3).strip()
                pri = re.search(r'\[(P[123])\]', answer)
                cur = {'id': m.group(1), 'title': title,
                       'answer': re.sub(r'\s*\[P[123]\]\s*', ' ', answer).strip(),
                       'why': '', 'round': None,
                       'priority': pri.group(1) if pri else None}
                continue
            if cur is None:
                continue
            w = re.match(r'^\s*\*Why:\*\s*(.*)$', line)
            if w:
                cur['why'] = w.group(1).strip()
            r = re.search(r'\(r(\d+)\)', line)
            if r and cur['round'] is None:
                cur['round'] = int(r.group(1))
            if cur['why'] and not w and line.strip() and not line.strip().startswith('-'):
                cur['why'] = (cur['why'] + ' ' + line.strip()).strip()
        if cur:
            out.append(cur)
        for e in out:
            e['why'] = re.sub(r'\s*\(r\d+\)\s*$', '', e['why']).strip()
        return out

    def settled_ids(self):
        return {e['id'] for e in self.settled()}

    def grounding_facts(self):
        """{n: text}"""
        out = {}
        for m in re.finditer(r'^\s*(\d+)\.\s+(.*)$',
                             self.section('Grounding facts') or '', re.M):
            out[m.group(1)] = m.group(2).strip()
        return out

    def adr_ids(self):
        return set(re.findall(r'\b(ADR-[\w.-]+)',
                              (self.section('Promoted to ADR') or '') + (self.section('Reads') or '')))

    def reads(self):
        out = []
        for line in (self.section('Reads') or '').splitlines():
            m = re.match(r'^\s*-\s+(\S.*?)\s*$', line)
            if not m:
                continue
            p = re.sub(r'\s*\([^)]*\)\s*$', '', m.group(1)).strip().strip('`')
            if p:
                out.append(p)
        return out

    def read_files(self):
        """Filenames citable as a source, from ## Reads and ## Principles in force."""
        out = set(self.reads())
        blob = (self.section('Reads') or '') + (self.section('Principles in force') or '')
        out |= set(re.findall(r'([\w./~-]+\.md)', blob))
        return out

    def ghost_reads(self, root, extra_roots=()):
        """## Reads entries that resolve to no file on disk.

        A principles file often lives outside the repo — `~/.claude/AGENTS.md`
        is where this machine keeps its only copy. Refusing to resolve it made a
        real, readable file report as invented, so an external path is expanded
        and checked rather than rejected on shape. Checked, not skipped: a typo
        in an absolute path is exactly as fatal at drafting time as a typo in a
        relative one."""
        roots = [root, *extra_roots]
        out = []
        for p in self.reads():
            if is_external_path(p):
                if not os.path.exists(os.path.expanduser(p)):
                    out.append(p)
                continue
            if not any(os.path.exists(os.path.join(r, p)) for r in roots) \
                    and not os.path.exists(p):
                out.append(p)
        return out

    def coverage(self):
        """[(category, state)] in table order."""
        cov = self.section('Coverage')
        if cov is None:
            return []
        rows = [(c.strip(), s.strip()) for c, s in
                re.findall(r'^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|', cov, re.M)]
        return [(c, s) for c, s in rows if c != 'Category' and set(c) - set('- ')]

    def deferred(self):
        return re.findall(r'\*\*(Q\d+)', self.section('Deferred') or '')

    def deferred_entries(self):
        out = []
        for line in (self.section('Deferred') or '').splitlines():
            m = re.match(r'^\s*-\s+\*\*(Q\d+)([^*]*)\*\*\s*(?:—|-)?\s*(.*)$', line)
            if m:
                out.append({'id': m.group(1), 'title': m.group(2).strip(),
                            'reason': m.group(3).strip()})
        return out

    # `- **Chosen (structure): C — …**` is what a drafter writes by reflex, and a
    # literal `Chosen:` match saw no chosen approach in it — then blamed the spec
    # for a fabricated citation. The axis is optional and repeatable: one round
    # can settle two independent strategy questions, and the skeleton's single
    # Chosen/Rejected pair modelled only one.
    CHOSEN = re.compile(r'^\s*(?:[-*+]\s+)?\*{0,2}\s*Chosen\s*(?:\(([^)]*)\))?\s*'
                        r'\*{0,2}\s*:\s*(.+?)\s*$', re.M)
    REJECTED = re.compile(r'^\s*(?:[-*+]\s+)?\*{0,2}\s*Rejected\s*(?:\(([^)]*)\))?\s*'
                          r'\*{0,2}\s*:\s*(.+?)\s*$', re.M)

    def strategy(self):
        body = self.section('Strategy') or ''

        def axes(rx):
            return [(m.group(1).strip() if m.group(1) else None,
                     m.group(2).strip().strip('*').strip())
                    for m in rx.finditer(body)]

        chosen, rejected = axes(self.CHOSEN), axes(self.REJECTED)

        def joined(pairs):
            if not pairs:
                return None
            return ' · '.join(f"({a}) {t}" if a else t for a, t in pairs)
        return {'chosen': joined(chosen), 'rejected': joined(rejected),
                'chosen_axes': chosen, 'rejected_axes': rejected}

    def question_ids(self):
        return set(re.findall(r'\*\*(Q\d+)', self.text))

    # -- protocol --------------------------------------------------------
    COUNTERS = ('questions', 'fact-finders', 'references', 'orchestrator reads',
                'lines read', 'critic passes')

    # The round cap per mode. It lives here so bump-protocol.sh cannot write a
    # record check-tree.sh rejects.
    ROUND_CAP = {'fast': 1, 'default': 4, 'deep': 5}

    # What each mode's own configuration spends before the interview asks
    # anything. A guard whose thresholds sit below these scores the mode, not
    # the pressure: `--deep` mandates four fact-finders, so a fixed `>= 3` trips
    # on a repo with a stack layer before question one and hands `--deep` a
    # single round. Thresholds are derived from the budget, never from a
    # constant that has to be remembered when the budget changes.
    FACT_FINDER_ALLOWANCE = {'fast': 1, 'default': 2, 'deep': 4}
    REFERENCE_BUDGET = {'fast': 7, 'default': 10, 'deep': 10}

    def protocol(self):
        p = self.section('Protocol') or ''

        def n(pat, cast=int):
            m = re.search(pat, p)
            if not m:
                return None
            try:
                return cast(m.group(1))
            except ValueError:
                return None
        return {
            'raw': p,
            'slug': n(r'Slug:\s*(\S+)', str),
            'mode': (n(r'Mode:\s*(\S+)', str) or '').lower() or None,
            'round': n(r'Round:\s*(\d+)'),
            'cap': n(r'Round:\s*\d+\s*of\s*(\d+)'),
            'next_phase': n(r'Next phase:\s*(\d+)'),
            'questions': n(r'questions\s+(\d+)'),
            'fact-finders': n(r'fact-finders\s+(\d+)'),
            'references': n(r'references\s+(\d+)'),
            'orchestrator reads': n(r'orchestrator reads\s+(\d+)'),
            'lines read': n(r'lines read\s+(\d+)'),
            'critic passes': n(r'critic passes\s+(\d+)'),
            'largest_read': n(r'Largest single read:\s*(\d+)'),
            'guard_tripped': bool(re.search(r'Guard:\s*tripped', p, re.I)),
        }

    # Context pressure is lines, not calls. Nine `Read` calls tripped the old
    # `orchestrator reads >= 8` on a run whose largest single read was 127
    # lines — most of them 20-40 line slices — while the counter that did track
    # size was never consulted. One counter now carries both.
    LINES_READ_THRESHOLD = 1200

    def thresholds(self, mode=None):
        """[(label, protocol key, threshold)] for this record's mode."""
        mode = (mode or self.protocol()['mode'] or 'default').lower()
        # +2, not +1: one follow-up dispatch and one degradation reference are
        # normal, and a guard that trips on the expected case is noise.
        return [('references loaded', 'references',
                 self.REFERENCE_BUDGET.get(mode, 10) + 2),
                ('fact-finder dispatches', 'fact-finders',
                 self.FACT_FINDER_ALLOWANCE.get(mode, 2) + 2),
                ('lines read', 'lines read', self.LINES_READ_THRESHOLD),
                ('rounds completed', 'round', 4),
                ('questions asked', 'questions', 22)]

    def guard_over(self):
        p = self.protocol()
        return [f"{label} {p[key]}≥{t}"
                for label, key, t in self.thresholds()
                if p.get(key) is not None and p[key] >= t]


# ----------------------------------------------------------------------- spec

# Identifiers are DEFINED only under ## Requirements and ## Success criteria.
# Everywhere else an FR-NNN is a reference, and conflating the two turns every
# acceptance scenario into a duplicate definition.
DEF_HEADS = ('requirements', 'functional requirements', 'success criteria')
SCEN_HEADS = ('acceptance scenarios', 'acceptance criteria')

ROUND_SUFFIX = re.compile(r'\s*\(r\d+\)\s*$')
# Tolerant of the markdown decoration a drafter reaches for by reflex.
DEF_LINE = re.compile(r'^\s*(?:[-*+]\s+)?\*{0,2}((?:FR|SC)-\d+[a-z]?)\*{0,2}\s*[:—–-]?\s+(\S.*)$')
MENTION = re.compile(r'(?:FR|SC)-\d')


def _norm(h):
    return re.sub(r'[^a-z ]', ' ', h.lower()).strip()


class Spec:
    """A parsed spec draft."""

    def __init__(self, text, path=None):
        self.text = text
        self.path = path
        self.lines = text.splitlines()
        self.sections = self._sections()

    @classmethod
    def load(cls, path):
        with open(path) as fh:
            return cls(fh.read(), path)

    def _sections(self):
        out, cur = [], None
        for i, l in enumerate(self.lines):
            m = re.match(r'^##\s+(.*?)\s*$', l)
            if not m:
                continue
            if cur:
                out.append((cur[0], cur[1], i - 1))
            cur = (_norm(m.group(1)), i + 1)
        if cur:
            out.append((cur[0], cur[1], len(self.lines) - 1))
        return out

    def spans(self, names):
        return [(a, b) for h, a, b in self.sections if h in names]

    def items(self):
        """[(id, text, tagline|None, lineno)] for every FR/SC definition."""
        out = []
        for a, b in self.spans(DEF_HEADS):
            for i in range(a, b + 1):
                m = DEF_LINE.match(self.lines[i])
                if not m:
                    continue
                tag = self.lines[i] if '←' in self.lines[i] else None
                if tag is None:
                    for j in range(i + 1, min(i + 4, len(self.lines))):
                        if '←' in self.lines[j]:
                            tag = self.lines[j]
                            break
                        if DEF_LINE.match(self.lines[j]):
                            break
                out.append((m.group(1), m.group(2), tag, i + 1))
        return out

    def unparsed_identifiers(self):
        claimed = {n - 1 for _, _, _, n in self.items()}
        return [(i + 1, self.lines[i].strip()[:60])
                for a, b in self.spans(DEF_HEADS) for i in range(a, b + 1)
                if i not in claimed and MENTION.search(self.lines[i]) and '←' not in self.lines[i]]

    def scenarios_body(self):
        return '\n'.join('\n'.join(self.lines[a:b + 1]) for a, b in self.spans(SCEN_HEADS))

    def stories(self):
        out = []
        for m in re.finditer(r'^\s*(?:[-*+]\s+)?\*{0,2}(P[123])\*{0,2}\s*[·:.\-—]\s*(.+)$',
                             self.text, re.M):
            out.append((m.group(1), m.group(2).strip()))
        return out

    def open_markers(self):
        return re.findall(r'\[NEEDS CLARIFICATION:\s*(.*?)\]', self.text, re.S)


def _canonical_source(seg, kind):
    """(canonical source, kind) for one comma-separated segment of a tag.

    `kind` carries the previous segment's type so a continuation resolves:
    `Grounding facts 15, 41` and `Settled Q2, Q9` each name two sources, and
    the second borrows its noun from the first. An unrecognised segment is
    returned verbatim with no kind, so the caller reports it rather than
    dropping it."""
    seg = ROUND_SUFFIX.sub('', seg).strip().strip('`').strip()
    if not seg:
        return None, kind
    m = re.fullmatch(r'Settled\s+(Q\d+)', seg)
    if m:
        return f'Settled {m.group(1)}', 'settled'
    m = re.fullmatch(r'Grounding facts?\s+(\d+)', seg)
    if m:
        return f'Grounding fact {m.group(1)}', 'fact'
    if seg == 'Strategy (chosen)':
        return seg, None
    m = re.fullmatch(r'Principle:\s*(\S+)', seg)
    if m:
        return f'Principle: {m.group(1)}', None
    if re.fullmatch(r'ADR-\S+', seg):
        return seg, None
    if re.fullmatch(r'[\w./~-]+\.md', seg):
        return seg, None
    if kind == 'fact' and re.fullmatch(r'\d+', seg):
        return f'Grounding fact {seg}', 'fact'
    if kind == 'settled' and re.fullmatch(r'Q\d+', seg):
        return f'Settled {seg}', 'settled'
    return seg, None


def tag_sources(tagline):
    """Every source named inside a `← ...` tag, in order, canonicalised.

    A tag may name several — `← Settled Q2 (r1), Settled Q9 (r2)` — and
    validating only the first is the check the malformed second one passes. It
    also cost a real answer its traceability row, because nothing downstream
    ever looked past the comma."""
    if not tagline or '←' not in tagline:
        return []
    out, kind = [], None
    for seg in tagline.split('←', 1)[1].split(','):
        src, kind = _canonical_source(seg, kind)
        if src:
            out.append(src)
    return out



def resolve_tag(src, record):
    """None if the tag resolves, else why it does not.

    Checking that a tag is merely *shaped* like a tag is the check a fabricated
    citation passes, which is why every caller goes through here."""
    if not src:
        return None
    where = f"the design record ({record.path})" if record.path else "the design record"
    q = re.match(r'Settled\s+(Q\d+)$', src)
    if q:
        return None if q.group(1) in record.settled_ids() \
            else f"no {q.group(1)} in the record's ## Settled"
    f = re.match(r'Grounding fact\s+(\d+)$', src)
    if f:
        return None if f.group(1) in record.grounding_facts() \
            else f"## Grounding facts has no item {f.group(1)}"
    if src == 'Strategy (chosen)':
        return None if record.strategy()['chosen'] \
            else f"{where} has a ## Strategy that names no chosen approach"
    p = re.match(r'Principle:\s*(\S+)$', src)
    if p:
        name = p.group(1).rstrip(':')
        files = record.read_files()
        return None if any(name in rf or rf in name for rf in files) \
            else f"{name} is not in ## Principles in force or ## Reads"
    a = re.match(r'(ADR-\S+)$', src)
    if a:
        return None if a.group(1) in record.adr_ids() \
            else f"{a.group(1)} is not in ## Promoted to ADR or ## Reads"
    if src.endswith('.md'):
        return None if src in record.read_files() \
            else f"{src} is not in {where}'s ## Reads"
    # Reached only by a segment no source form recognised. Returning None here
    # is how `Deferred Q8` rode into a spec behind a valid `Settled Q5`: an
    # unrecognised source is not a resolved one.
    return (f"'{src}' is not a source form — valid: Settled Q<n> | "
            f"Grounding fact <n> | Strategy (chosen) | Principle: <file> | "
            f"ADR-<id> | a ## Reads file")


# ----------------------------------------------------------------------- plan

# The plan format lives in references/plan-template.md, and this is the only
# thing that parses it — same rule the design record and the spec are under.
# An empty section is written as an italic placeholder rather than deleted, so
# a reader can tell "nothing to say" from "nobody thought about it". Every
# accessor treats such a line as empty.

TASK_ID = re.compile(r'^T\d{2,}$')
TASK_FILE = re.compile(r'^T(\d{2,})\.md$')
STATUSES = ('Planned', 'In progress', 'Done', 'Blocked')
IDENT = re.compile(r'(?:FR|SC)-\d+[a-z]?')
DASHES = ('—', '–', '-')


def _placeholder(line):
    """True for the italic 'nothing to say here' line the template prescribes."""
    s = line.strip().lstrip('-*+ ').strip()
    return s.startswith('_') and s.endswith('_')


def _bullets(body):
    """Bullet lines of a section, placeholders dropped, continuations joined."""
    out = []
    for line in (body or '').splitlines():
        if not line.strip():
            continue
        if re.match(r'^\s*[-*+]\s+', line):
            if _placeholder(line):
                continue
            out.append(re.sub(r'^\s*[-*+]\s+', '', line).rstrip())
        elif out and line.startswith((' ', '\t')):
            out[-1] += ' ' + line.strip()
    return out


class _Doc:
    """Shared `## section` addressing for the plan and its task files."""

    def __init__(self, text, path=None):
        self.text = text
        self.path = path
        self.lines = text.splitlines()

    @classmethod
    def load(cls, path):
        with open(path) as fh:
            return cls(fh.read(), path)

    def section(self, name):
        m = re.search(rf'^##\s+{re.escape(name)}[^\n]*$(.*?)(?=^## |\Z)',
                      self.text, re.M | re.S)
        return m.group(1) if m else None

    def headings(self):
        return [_norm(m.group(1)) for m in re.finditer(r'^##\s+(.*?)\s*$', self.text, re.M)]


class Plan(_Doc):
    """A parsed `plan.md`. The task-graph table is derived from the task files,
    so everything read from it exists to be compared against them, never trusted."""

    REQUIRED = ['Approach', 'Milestones', 'Task graph', 'Not planned',
                'Enabling work', 'Plan assumptions', 'Open questions carried from the spec']

    def missing_sections(self):
        have = self.headings()
        return [s for s in self.REQUIRED if _norm(s) not in have]

    def graph_rows(self):
        """[{task, title, covers[], depends[], milestone, status}] from the table."""
        out = []
        body = self.section('Task graph') or ''
        for line in body.splitlines():
            if not line.strip().startswith('|'):
                continue
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if len(cells) < 6 or not TASK_ID.match(cells[0]):
                continue
            out.append({
                'task': cells[0], 'title': cells[1],
                'covers': _idents(cells[2]), 'depends': _tasks(cells[3]),
                'milestone': cells[4], 'status': cells[5],
            })
        return out

    def milestones(self):
        """[(id, title, [task ids])] in declared order."""
        out = []
        for line in _bullets(self.section('Milestones')):
            m = re.match(r'\*{0,2}(M\d+)\*{0,2}\s*[—–-]\s*(.*?)\*{0,2}\s*:\s*(.*)$', line)
            if m:
                out.append((m.group(1), m.group(2).strip(), _tasks(m.group(3))))
        return out

    def milestone_ids(self):
        return [m[0] for m in self.milestones()]

    def not_planned(self):
        """[(identifier, reason)] — an identifier with no reason returns ''."""
        out = []
        for line in _bullets(self.section('Not planned')):
            ids = IDENT.findall(line)
            reason = re.split(r'\s[—–-]\s', line, 1)
            for i in ids:
                out.append((i, reason[1].strip() if len(reason) > 1 else ''))
        return out

    def enabling_tasks(self):
        return sorted({t for line in _bullets(self.section('Enabling work'))
                       for t in _tasks(line)})

    def assumptions(self):
        """[(text, reversal cost or None)] — the cost is what R21 is about."""
        out = []
        for line in _bullets(self.section('Plan assumptions')):
            m = re.search(r'\*\*Revers(?:ing|al)[^:]*:\*\*\s*(.+)$', line)
            out.append((line, m.group(1).strip() if m else None))
        return out

    def seams(self):
        """[(path, source tag or None)] from ## Seams. Absent section → []."""
        out = []
        for line in _bullets(self.section('Seams')):
            body, tag = (line.split('←', 1) + [None])[:2]
            head = re.split(r'\s[—–]\s', body, 1)[0].strip().strip('`')
            if head:
                out.append((head, tag.strip() if tag else None))
        return out

    def open_markers(self):
        return re.findall(r'\[NEEDS CLARIFICATION:\s*(.*?)\]', self.text, re.S)


class Task(_Doc):
    """A parsed `tasks/T0N.md`. The authoritative source for its own status."""

    def ident(self):
        m = re.match(r'^#\s+(T\d{2,})\b', self.text)
        return m.group(1) if m else None

    def title(self):
        m = re.match(r'^#\s+T\d{2,}\s*[—–-]\s*(.+?)\s*$', self.text, re.M)
        return m.group(1) if m else ''

    def field(self, name):
        m = re.search(rf'^{re.escape(name)}:\s*(.*?)\s*$', self.text, re.M)
        if not m:
            return None
        v = m.group(1).strip()
        return '' if v in DASHES else v

    def covers(self):
        return _idents(self.field('Covers') or '')

    def depends(self):
        return _tasks(self.field('Depends on') or '')

    def touches(self):
        raw = self.field('Touches') or ''
        return [p.strip().strip('`') for p in raw.split(',') if p.strip()]

    def status(self):
        return self.field('Status') or ''

    def action_items(self):
        return [re.sub(r'^\s*[-*+]\s*\[[ xX]\]\s*', '', l).strip()
                for l in (self.section('Action items') or '').splitlines()
                if re.match(r'^\s*[-*+]\s*\[[ xX]\]', l)]

    def done_when(self):
        """[(identifier, quoted text)] for each done-condition naming an FR/SC."""
        out = []
        for line in _bullets(self.section('Done when')):
            m = re.match(r'\*{0,2}((?:FR|SC)-\d+[a-z]?)\*{0,2}\s+(.*)$', line)
            if m:
                out.append((m.group(1), m.group(2).strip()))
        return out


def _idents(cell):
    return IDENT.findall(cell or '')


def _tasks(cell):
    return re.findall(r'\bT\d{2,}\b', cell or '')


def load_tasks(tasks_dir):
    """[(id, Task)] sorted by id. A filename that is not T0N.md is not a task."""
    out = []
    if not os.path.isdir(tasks_dir):
        return out
    for name in sorted(os.listdir(tasks_dir)):
        if TASK_FILE.match(name):
            out.append((name[:-3], Task.load(os.path.join(tasks_dir, name))))
    return out


def dependency_cycles(edges):
    """[[task ids]] — one entry per cycle found. edges: {task: [depends on]}."""
    cycles, state, stack = [], {}, []

    def walk(n):
        state[n] = 1
        stack.append(n)
        for d in edges.get(n, []):
            if state.get(d) == 1:
                cycles.append(stack[stack.index(d):] + [d])
            elif state.get(d, 0) == 0 and d in edges:
                walk(d)
        stack.pop()
        state[n] = 2

    for n in edges:
        if state.get(n, 0) == 0:
            walk(n)
    return cycles
