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


def search_roots(root):
    """`root` and every ancestor of it, nearest first.

    Paths in a record are written from the repository root, but a record can sit
    in a nested checkout or be checked from a hook whose cwd is unrelated. A real
    file resolves against one of these; an invented one resolves against none."""
    out, cur = [], os.path.abspath(root)
    while True:
        out.append(cur)
        parent = os.path.dirname(cur)
        if parent == cur:
            return out
        cur = parent


def resolve_path(p, roots):
    """The existing file `p` names, or None."""
    if is_external_path(p):
        full = os.path.expanduser(p)
        return full if os.path.exists(full) else None
    for r in roots:
        cand = os.path.join(r, p)
        if os.path.exists(cand):
            return cand
    return None


def wording_overlap(text, source):
    """Share of `text` that is `source`'s own wording, 0.0 to 1.0, or None
    when `text` is too short to judge.

    A word counts when it sits inside a run of consecutive words the source
    also has, so a sentence copied and trimmed scores high, a few words added
    to a copied phrase cost only those words, and a paraphrase scores near zero
    whatever vocabulary it shares."""
    words = re.findall(r'[0-9a-z]+', text.casefold())
    if len(words) < 4:
        return None
    n = 4 if len(words) >= 8 else 3
    have = re.findall(r'[0-9a-z]+', source.casefold())
    runs = {tuple(have[i:i + n]) for i in range(len(have) - n + 1)}
    covered = set()
    for i in range(len(words) - n + 1):
        if tuple(words[i:i + n]) in runs:
            covered.update(range(i, i + n))
    return len(covered) / len(words)


# A citation is a backticked `path:line`, optionally a range. The last path
# segment has to carry an extension: `ghcr.io/acme/api:3` and `localhost:8080`
# have the same shape and are not files.
CITATION = re.compile(r'`([^`\s:]*[^`\s:/]\.\w+):(\d+)(?:[-–]\d+)?`')
# `:349` after a full citation points into the same file.
CITATION_SHORT = re.compile(r'`:(\d+)(?:[-–]\d+)?`')
FACT_SUFFIX = re.compile(r'\(([^()]+),\s*r(\d+),\s*(high|medium|low)\)\s*$')
FACT_VERDICT = re.compile(r'(?:—|–|-)\s*(contradicted|unverifiable)\b', re.I)


# --------------------------------------------------------------------- record


class Record:
    """A parsed `tree.md`. Every accessor returns something empty rather than
    raising, because a partially written record is the normal mid-interview
    state."""

    REQUIRED = ['Problem', 'Protocol', 'Reads', 'Coverage', 'Principles in force',
                'Grounding facts', 'Settled', 'Frontier', 'Blocked', 'Deferred', 'Sessions']

    SETTLED_ENTRY = re.compile(r'^-\s+\*\*(Q\d+)([^*]*)\*\*\s*(?:→|->)\s*(.*)$')
    DEFERRED_ENTRY = re.compile(r'^-\s+\*\*(Q\d+)([^*]*)\*\*\s*(?:—|–|-)?\s*(.*)$')

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

    # -- content ---------------------------------------------------------
    def problem(self):
        body = self.section('Problem') or ''
        return ' '.join(l.strip() for l in body.splitlines() if l.strip())

    def settled(self):
        """[{id, title, answer, why, round, priority}] in record order.

        An answer may run over indented lines before its `*Why:*`; they are part
        of it. A struck-through entry is superseded: it and the lines under it
        are skipped, so its rationale cannot leak into the entry above."""
        out = []
        cur = None
        for line in (self.section('Settled') or '').splitlines():
            if not line.strip():
                continue
            if re.match(r'^-\s', line):
                m = self.SETTLED_ENTRY.match(line)
                if not m:
                    cur = None
                    continue
                answer = m.group(3).strip()
                pri = re.search(r'\[(P[123])\]', answer)
                cur = {'id': m.group(1), 'title': m.group(2).strip(),
                       'answer': answer, 'why': None, 'round': None,
                       'priority': pri.group(1) if pri else None}
                out.append(cur)
                continue
            if cur is None or line.strip().startswith('~~'):
                continue
            w = re.match(r'^\s*\*Why:\*\s*(.*)$', line)
            if w:
                cur['why'] = w.group(1).strip()
            elif cur['why'] is None:
                cur['answer'] = (cur['answer'] + ' ' + line.strip()).strip()
            else:
                cur['why'] = (cur['why'] + ' ' + line.strip()).strip()
        for e in out:
            r = re.search(r'\(r(\d+)\)', (e['why'] or '') + ' ' + e['answer'])
            e['round'] = int(r.group(1)) if r else None
            e['why'] = re.sub(r'\s*\(r\d+\)\s*$', '', e['why'] or '').strip()
            e['answer'] = re.sub(r'\s*\(r\d+\)\s*$', '', e['answer'])
            e['answer'] = re.sub(r'\s*\[P[123]\]\s*', ' ', e['answer']).strip()
        return out

    def settled_ids(self):
        return {e['id'] for e in self.settled()}

    def unparsed_entries(self, name):
        """Live top-level bullets under `## Settled` or `## Deferred` that the
        entry parser cannot read.

        Such a line looks like an entry to a person and is invisible to every
        tool: the decision it holds resolves no tag and reaches no packet."""
        rx = self.SETTLED_ENTRY if name == 'Settled' else self.DEFERRED_ENTRY
        return [l.strip() for l in (self.section(name) or '').splitlines()
                if re.match(r'^-\s', l) and not rx.match(l)
                and not l.lstrip('- ').startswith('~~')]

    def grounding_fact_list(self):
        """[(n, text)] for every top-level numbered item, in order, duplicates
        kept. Indented lines under an item belong to it."""
        out = []
        for line in (self.section('Grounding facts') or '').splitlines():
            m = re.match(r'^(\d+)\.\s+(.*)$', line)
            if m:
                out.append([m.group(1), m.group(2).strip()])
            elif out and line.strip() and line[:1] in (' ', '\t'):
                out[-1][1] += ' ' + line.strip()
        return [(n, t) for n, t in out]

    def grounding_facts(self):
        """{n: text}. A number used twice keeps the first; `check-tree.sh`
        fails the record for the second."""
        out = {}
        for n, text in self.grounding_fact_list():
            out.setdefault(n, text)
        return out

    def adr_ids(self):
        """`ADR-<id>` for every ADR file `## Reads` names.

        The id is the file's leading number, or its whole stem when the file
        is not numbered. An ADR listed under `## Promoted to ADR` with no file
        behind it is a title, and a title is not a source."""
        out = set()
        for p in self.reads():
            stem = os.path.splitext(os.path.basename(p))[0]
            if not re.search(r'(^|/)(adrs?|decisions?)/', p.lower()) \
                    and not stem.lower().startswith('adr-'):
                continue
            stem = re.sub(r'^adr-', '', stem, flags=re.I)
            num = re.match(r'(\d+)-(?!\d)', stem)
            out.add(f"ADR-{num.group(1)}" if num else f"ADR-{stem}")
        return out

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
        return [p for p in self.reads() if resolve_path(p, roots) is None]

    def fact_citations(self, text):
        """[(path, line)] for every `path:line` a grounding fact cites. A bare
        `:349` takes the path of the citation before it."""
        out, last = [], None
        for m in re.finditer(r'`[^`]*`', text):
            full = CITATION.fullmatch(m.group(0))
            short = CITATION_SHORT.fullmatch(m.group(0))
            if full and not full.group(1).startswith('//'):
                last = full.group(1)
                out.append((last, int(full.group(2))))
            elif short and last:
                out.append((last, int(short.group(1))))
        return out

    def coverage(self):
        """[(category, state)] in table order."""
        cov = self.section('Coverage')
        if cov is None:
            return []
        rows = [(c.strip(), s.strip()) for c, s in
                re.findall(r'^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|', cov, re.M)]
        return [(c, s) for c, s in rows if c != 'Category' and set(c) - set('- ')]

    def deferred_entries(self):
        out = []
        for line in (self.section('Deferred') or '').splitlines():
            m = self.DEFERRED_ENTRY.match(line)
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

    # -- protocol --------------------------------------------------------
    def protocol(self):
        """The fields that re-anchor a run. A record may also carry Mode,
        Counters and Guard lines; they are not read, so such a record still
        resumes."""
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
            'round': n(r'Round:\s*(\d+)'),
            'cap': n(r'Round:\s*\d+\s*of\s*(\d+)'),
            'next_phase': n(r'Next phase:\s*(\d+)'),
        }


# ----------------------------------------------------------------------- spec

# Identifiers are DEFINED only under ## Requirements and ## Success criteria.
# Everywhere else an FR-NNN is a reference, and conflating the two turns every
# acceptance scenario into a duplicate definition.
DEF_HEADS = ('requirements', 'functional requirements', 'success criteria')
SCEN_HEADS = ('acceptance scenarios', 'acceptance criteria')
SCOPE_HEADS = ('out of scope', 'non goals', 'nongoals')
CONSTRAINT_HEADS = ('implementation constraints',)
# The sections spec-template.md defines. A statement under any other heading is
# read by no checker and reaches no critic, so the heading itself is the finding.
KNOWN_HEADS = (('user stories',), ('requirements', 'functional requirements'),
               ('success criteria',), SCEN_HEADS, SCOPE_HEADS, CONSTRAINT_HEADS,
               ('chosen approach',), ('principle deviations',), ('clarifications',),
               ('open questions',))

ROUND_SUFFIX = re.compile(r'\s*\(r\d+\)\s*$')
# Tolerant of the markdown decoration a drafter reaches for by reflex.
DEF_LINE = re.compile(r'^\s*(?:[-*+]\s+)?\*{0,2}((?:FR|SC)-\d+[a-z]?)\*{0,2}\s*[:—–-]?\*{0,2}\s+(\S.*)$')
SCEN_LINE = re.compile(r'^\s*(?:[-*+]\s+|#{3,}\s+)?\*{0,2}(FR-\d+[a-z]?)\b')
WITHDRAWN = re.compile(r'\(withdrawn\b', re.I)


def _norm(h):
    return re.sub(r'[^a-z ]', ' ', h.lower()).strip()


class Spec:
    """A parsed spec draft."""

    def __init__(self, text, path=None):
        self.text = text
        self.path = path
        self.lines = text.splitlines()
        self.sections = self._sections()
        self._defs = None

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

    def _definitions(self):
        """Classify every line of the requirement sections.

        An item is its definition line, the indented lines under it, and the
        `←` line that closes it. Anything else in these sections is a statement
        with no identifier, which no tag covers and no critic is shown."""
        if self._defs is not None:
            return self._defs
        items, tag_lines, strays = [], set(), []
        for a, b in self.spans(DEF_HEADS):
            cur = None
            for i in range(a, b + 1):
                line = self.lines[i]
                if not line.strip():
                    cur = None
                    continue
                m = DEF_LINE.match(line)
                if m:
                    cur = {'id': m.group(1), 'text': m.group(2).split('←')[0].strip(),
                           'tag': line if '←' in line else None, 'line': i + 1}
                    if cur['tag']:
                        tag_lines.add(i + 1)
                    items.append(cur)
                    continue
                if cur is not None and line.lstrip().startswith('←'):
                    cur['tag'] = line if cur['tag'] is None \
                        else cur['tag'] + ', ' + line.split('←', 1)[1]
                    tag_lines.add(i + 1)
                    continue
                if cur is not None and cur['tag'] is None and line[:1] in (' ', '\t'):
                    cur['text'] += ' ' + line.strip()
                    continue
                if re.match(r'^#{3,}\s', line) or _placeholder(line) \
                        or re.fullmatch(r'\s*[-*_]{3,}\s*', line):
                    cur = None
                    continue
                strays.append((i + 1, line.strip()[:70]))
        self._defs = (items, tag_lines, strays)
        return self._defs

    def items(self):
        """[(id, text, tagline|None, lineno)] for every FR/SC definition."""
        return [(d['id'], d['text'], d['tag'], d['line']) for d in self._definitions()[0]]

    def item_tag_lines(self):
        """Line numbers of the `←` lines that belong to an FR/SC definition."""
        return self._definitions()[1]

    def stray_lines(self):
        """[(lineno, text)] for lines in the requirement sections that belong to
        no identifier."""
        return self._definitions()[2]

    def unknown_sections(self):
        """[(heading as written, lineno)] for `## ` headings the template does
        not define."""
        known = {h for group in KNOWN_HEADS for h in group}
        return [(self.lines[a - 1].strip(), a) for h, a, _b in self.sections if h not in known]

    def repeated_sections(self):
        """Names of template sections the spec carries more than once, counting
        an alias as the same section."""
        have = [h for h, _a, _b in self.sections]
        return [group[0] for group in KNOWN_HEADS if sum(have.count(h) for h in group) > 1]

    def bullets(self, names):
        """[(lineno, text)] for each bullet of the first section in `names`,
        continuation lines joined, placeholders dropped."""
        out = []
        for a, b in self.spans(names)[:1]:
            for i in range(a, b + 1):
                line = self.lines[i]
                if not line.strip():
                    continue
                if re.match(r'^\s*[-*+]\s+', line):
                    if not _placeholder(line):
                        out.append([i + 1, re.sub(r'^\s*[-*+]\s+', '', line).rstrip()])
                elif out and line[:1] in (' ', '\t'):
                    out[-1][1] += ' ' + line.strip()
        return [(n, t) for n, t in out]

    def scenarios_body(self):
        return '\n'.join('\n'.join(self.lines[a:b + 1]) for a, b in self.spans(SCEN_HEADS))

    def scenario_ids(self):
        """[(id, lineno)] for each scenario, keyed by the requirement that opens
        its line. A requirement merely mentioned in a sentence is not covered."""
        return [(m.group(1), i + 1) for a, b in self.spans(SCEN_HEADS)
                for i in range(a, b + 1) for m in [SCEN_LINE.match(self.lines[i])] if m]

    def intro(self):
        """The paragraph between the title and the first section."""
        end = self.sections[0][1] - 1 if self.sections else len(self.lines)
        return '\n'.join(l for l in self.lines[:end] if l.strip() and not l.startswith('# ')).strip()

    def stories(self):
        out = []
        for m in re.finditer(r'^\s*(?:[-*+]\s+)?\*{0,2}(P[123])\*{0,2}\s*[·:.\-—]\s*(.+)$',
                             self.text, re.M):
            out.append((m.group(1), m.group(2).strip()))
        return out

    def open_markers(self):
        return re.findall(r'\[NEEDS CLARIFICATION:\s*(.*?)\]', self.text, re.S)

    def section_text(self, *names):
        """Body of the first section whose heading matches one of `names`
        (lower-case, punctuation stripped), or None when the spec has none."""
        for h, a, b in self.sections:
            if h in names:
                return '\n'.join(self.lines[a:b + 1])
        return None

    def all_tags(self):
        """[(lineno, line)] for every line carrying a `←` source tag.

        Requirements are not the only statements that cite the record: an
        out-of-scope line and an implementation constraint each come from a
        decision too, and a citation is a citation wherever it sits."""
        return [(i + 1, l) for i, l in enumerate(self.lines) if '←' in l]


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
        return None if any(rf == name or rf.endswith('/' + name) or name.endswith('/' + rf)
                           for rf in files) \
            else f"{name} is not in ## Principles in force or ## Reads"
    a = re.match(r'(ADR-\S+)$', src)
    if a:
        return None if a.group(1) in record.adr_ids() \
            else f"## Reads names no ADR file with the id {a.group(1)[4:]}"
    if re.fullmatch(r'[\w./~-]+\.\w+', src):
        return (f"{src} is a file, and a file is not a source — cite the Settled "
                f"entry or the grounding fact that came from it")
    # Reached only by a segment no source form recognised. Returning None here
    # is how `Deferred Q8` rode into a spec behind a valid `Settled Q5`: an
    # unrecognised source is not a resolved one.
    return (f"'{src}' is not a source form — valid: Settled Q<n> | "
            f"Grounding fact <n> | Strategy (chosen) | Principle: <file> | ADR-<id>")


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
