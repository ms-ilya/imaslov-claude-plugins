# ABOUTME: Gates the rule catalogue — structural self-check, pattern self-check, and citation resolution against Apple's text.
#
# Two jobs, and they run at different times:
#
#   Authoring — every rule record is well-formed, every id unique, every
#   detection pattern compiles, every guidance slug resolves to prose that
#   exists. A pattern that does not compile is a rule that can never fire, and
#   is indistinguishable from a rule that simply never matches.
#
#   Audit runtime — Phase 1 points APPSTORE_GUIDELINE_TEXT at the text it just
#   retrieved from Apple and re-runs this, so a rule whose number has drifted is
#   withheld from that run rather than cited wrongly. Apple reuses and retires
#   numbers: 2.5.10 resolves but is marked "Intentionally omitted", and Push
#   Notifications moved from 4.5.5 to 4.5.4, where 4.5.5 now means Game Center
#   Player IDs. Existence alone cannot catch that, so the check compares the
#   catalogue's claim against the text under the number.
#
# The rule record's shape is declared as RECORD below rather than in a separate
# schema file. It is read by exactly one consumer, and a schema nobody else
# loads is a second place for the same statement to drift.

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.dirname(os.path.dirname(HERE))

CATEGORIES = ["safety", "performance", "business", "design", "legal"]
SOURCES = ["justinperea", "cruisediary", "devsemih", "safaiyeh", "apple"]

# --------------------------------------------------------------------------
# The shape of one rule record.
#
# Six fields are load-bearing: identity, guideline number, severity,
# verifiability, detection patterns and source attribution. Rejection cases came
# seventh. The rest grew during authoring.
# --------------------------------------------------------------------------

CLAUSE = {
    "required": ["kind", "present"],
    "fields": {
        # symbol matches a literal identifier in source; regex matches a pattern;
        # plist_key/plist_value/entitlement/build_setting address structured
        # inputs by key; file asserts a file class exists; dependency matches a
        # package name; always is unconditional, and is how a checklist item that
        # applies to every project is written.
        "kind": {"enum": ["symbol", "regex", "plist_key", "plist_value", "entitlement",
                          "file", "build_setting", "dependency", "always"]},
        "file_class": {"enum": ["swift", "objc", "info_plist", "entitlements",
                                "privacy_manifest", "pbxproj", "asset_catalog",
                                "package_manifest", "any"]},
        "key": {"type": str, "min": 1},
        "pattern": {"type": str, "min": 1},
        "equals": {"type": str},
        # `present: false` is how absence is expressed — the missing usage
        # description, the absent privacy manifest. Absence is most of this
        # catalogue, so it is a first-class clause rather than a negation wrapper.
        "present": {"type": bool},
        # Marks the clause whose match location becomes the finding's file and
        # line. For a missing NSCameraUsageDescription that is the AVCaptureDevice
        # call, not the Info.plist that lacks the key: the line a developer needs
        # is the one making the call.
        "evidence": {"type": bool},
        # A false-positive carve-out the subagent must apply before emitting.
        "note": {"type": str, "min": 1},
    },
}

DETECTION = {
    "required": ["match", "clauses"],
    "fields": {
        "match": {"enum": ["all_of", "any_of"]},
        "clauses": {"list_of": CLAUSE, "min": 1},
    },
}

CASE = {
    "required": ["symptom", "source", "root_cause"],
    "fields": {
        "symptom": {"type": str, "min": 10},
        # A rejection anecdote nobody can check is the folklore this catalogue
        # exists to replace, so a case with no source URL does not enter it.
        "source": {"type": str, "pattern": r"^https?://"},
        "root_cause": {"type": str, "min": 20},
        "itms": {"type": str, "pattern": r"^ITMS-[0-9]+$"},
    },
}

STATEMENT = {
    "required": ["source", "says"],
    "fields": {
        "source": {"enum": SOURCES},
        "says": {"type": str, "min": 20},
        "stricter_than_apple": {"type": bool},
    },
}

APPLIES_TO = {
    "required": [],
    "fields": {
        "storefronts": {"list_of": {"type": str, "min": 2}, "min": 1},
        "effective": {"type": str, "min": 4},
    },
}

RECORD = {
    "required": ["id", "title", "guideline", "severity", "verifiability",
                 "detection", "sources", "resolutions"],
    "fields": {
        # Stable and opaque. It does NOT encode the guideline number: a
        # number-derived key would have to be rewritten every time Apple
        # renumbers, and Apple renumbers.
        "id": {"type": str, "min": 6, "pattern": r"^[a-z0-9]+(-[a-z0-9]+)*$"},
        "title": {"type": str, "min": 8},
        # Null is permitted — export compliance is an App Store Connect
        # requirement rather than a numbered clause. The count is reported so the
        # number of anchorless rules cannot creep up unnoticed.
        "guideline": {"type": str, "null_ok": True, "pattern": r"^[1-5](\.[0-9]+)*(\([a-z]+\))?$"},
        "severity": {"enum": ["critical", "warning", "suggestion"]},
        # The CEILING for findings from this rule, not the grade of any one
        # finding. A PROVEN rule may emit PROBABLE; it may never emit better.
        "verifiability": {"enum": ["PROVEN", "PROBABLE", "MANUAL"]},
        "detection": {"object": DETECTION},
        "sources": {"list_of": {"enum": SOURCES}, "min": 1},
        # Defaults a finding starts from. A subagent may narrow these to the
        # project it saw, but may not reduce a two-sided fix to one side.
        "resolutions": {"list_of": {"type": str, "min": 10}, "min": 1},
        "cases": {"list_of": CASE},
        # Present only where two upstream sources state the rule with different
        # strictness. Two entries minimum, because one statement is not a conflict.
        "statements": {"list_of": STATEMENT, "min": 2},
        "applies_to": {"object": APPLIES_TO},
        # Anchor slug in references/detection-<category>.md. Prose is held out of
        # the catalogue so the catalogue stays parseable.
        "guidance": {"type": str, "min": 3},
        "why": {"type": str, "min": 20},
        "why_manual": {"type": str, "min": 10},
    },
}

FILE = {
    "required": ["category", "rules"],
    "fields": {
        "category": {"enum": CATEGORIES},
        "rules": {"list_of": RECORD, "min": 1},
    },
}


def check_shape(value, spec, path, out):
    """Validates one value against a field spec, appending 'path: message' strings."""
    if "object" in spec:
        return check_object(value, spec["object"], path, out)
    if "list_of" in spec:
        if not isinstance(value, list):
            out.append(f"{path}: expected a list, got {type(value).__name__}")
            return out
        if len(value) < spec.get("min", 0):
            out.append(f"{path}: needs at least {spec['min']} item(s), has {len(value)}")
        for i, item in enumerate(value):
            check_shape(item, item_spec(spec["list_of"]), f"{path}[{i}]", out)
        return out
    if "enum" in spec:
        if value not in spec["enum"]:
            out.append(f"{path}: {value!r} is not one of {spec['enum']}")
        return out
    if value is None and spec.get("null_ok"):
        return out
    wanted = spec.get("type")
    if wanted is not None:
        # bool is a subclass of int; nothing here wants an int, so an exact-type
        # test is enough and keeps `present: 1` from passing as a boolean.
        if type(value) is not wanted:
            out.append(f"{path}: expected {wanted.__name__}, got {type(value).__name__}")
            return out
    if isinstance(value, str):
        if len(value) < spec.get("min", 0):
            out.append(f"{path}: needs at least {spec['min']} characters, has {len(value)}")
        if "pattern" in spec and not re.search(spec["pattern"], value):
            out.append(f"{path}: {value!r} does not match {spec['pattern']}")
    return out


def item_spec(spec):
    """A list's item spec is either a nested record or a plain field spec."""
    return {"object": spec} if "fields" in spec else spec


def check_object(doc, spec, path, out):
    if not isinstance(doc, dict):
        out.append(f"{path}: expected an object, got {type(doc).__name__}")
        return out
    for key in spec["required"]:
        if key not in doc:
            out.append(f"{path}: missing required field {key!r}")
    for key, value in doc.items():
        if key not in spec["fields"]:
            out.append(f"{path}: unexpected field {key!r} — the record is closed")
            continue
        check_shape(value, spec["fields"][key], f"{path}.{key}", out)
    return out


# --------------------------------------------------------------------------
# Apple's guideline text
# --------------------------------------------------------------------------

# Apple writes each numbered clause as a bold-opened list item. The number is
# followed by section markers (![ASR & NR]) or a title before the closing bold,
# so anchoring on "- **" and reading the number off the front is the only form
# that survives all five sections.
#
# The trailing boundary is a lookahead rather than \b, because \b cannot match
# between ")" and a space: with \b the parenthetical group was unreachable and
# every sub-clause collapsed onto its parent — 5.1.1(i) indexed as 5.1.1. That
# was not cosmetic. build_index keeps the longest body per key, so a parent
# retired as "Intentionally omitted" was overwritten by a longer sub-clause and
# the omitted flag was lost, which is precisely the drift this check exists to
# catch.
CLAUSE_LINE = re.compile(r'^\s*[-*]\s+\*\*((?:[1-5])(?:\.[0-9]+)*(?:\([a-z]+\))?)(?=[\s*]|$)')
OMITTED = re.compile(r'intentionally\s+omitted', re.I)


def build_index(text):
    """Maps guideline number -> {'text': str, 'omitted': bool}.

    A number that resolves is not the same as a number that means something, so
    omitted numbers are recorded rather than dropped: a rule citing 2.5.10 can
    only fail if the checker knows the number is present-but-void.
    """
    index = {}
    lines = text.splitlines()
    for i, line in enumerate(lines):
        m = CLAUSE_LINE.match(line)
        if not m:
            continue
        number = m.group(1)
        body = [line]
        for nxt in lines[i + 1:]:
            if CLAUSE_LINE.match(nxt) or nxt.startswith('#'):
                break
            body.append(nxt)
        blob = '\n'.join(body).strip()
        # A number can appear more than once (a cross-reference inside another
        # clause). Keep the longest body, which is the definition rather than
        # the mention.
        if number not in index or len(blob) > len(index[number]['text']):
            index[number] = {'text': blob, 'omitted': bool(OMITTED.search(blob))}
    return index


# --------------------------------------------------------------------------
# The gate
# --------------------------------------------------------------------------

class Report:
    def __init__(self):
        self.failures = []
        self.notes = []
        self.skipped = []

    def fail(self, mode, where, message, expected=None):
        self.failures.append((mode, where, message, expected))

    def note(self, message):
        self.notes.append(message)

    def skip(self, message, detail=None):
        self.skipped.append((message, detail))

    def render(self):
        for message in self.notes:
            print(f"ok    {message}")
        for message, detail in self.skipped:
            print(f"skip  {message}")
            if detail:
                print(f"      {detail}")
        for mode, where, message, expected in self.failures:
            print(f"FAIL  [{mode}] {where}: {message}")
            if expected:
                print(f"      expected: {expected}")
        return len(self.failures)


def check_rule_semantics(rule, where, report):
    """Constraints the record shape cannot state, because they relate fields."""
    detection = rule.get("detection") or {}
    clauses = detection.get("clauses") or []
    evidence = [c for c in clauses if isinstance(c, dict) and c.get("evidence")]

    if len(evidence) > 1:
        report.fail(
            "unclear", where,
            f"{len(evidence)} clauses are marked as the evidence clause",
            "exactly one clause supplies the file and line a finding points at",
        )

    if rule.get("verifiability") == "PROVEN":
        if detection.get("match") == "all_of" and len(evidence) != 1:
            report.fail(
                "not-actionable", where,
                "a PROVEN rule whose clauses must all match names no evidence clause",
                "mark the clause whose match location becomes the finding's file and line",
            )
        if clauses and all(c.get("kind") == "always" for c in clauses if isinstance(c, dict)):
            report.fail(
                "not-actionable", where,
                "a PROVEN rule detects unconditionally, so it can never carry evidence",
                "a rule that always fires is MANUAL, not PROVEN",
            )

    if rule.get("verifiability") == "MANUAL" and not rule.get("why_manual"):
        report.fail(
            "not-actionable", where,
            "a MANUAL rule does not say why code cannot decide it",
            "state what lives outside the repository — a live URL, a backend, App Store Connect state",
        )

    for i, clause in enumerate(clauses):
        if not isinstance(clause, dict):
            continue
        kind = clause.get("kind")
        if kind in ("plist_key", "plist_value", "entitlement", "build_setting") and not clause.get("key"):
            report.fail("unclear", f"{where} clause {i}", f"a {kind} clause names no key",
                        "add the key it addresses")
        if kind in ("symbol", "regex", "dependency") and not clause.get("pattern"):
            report.fail("unclear", f"{where} clause {i}", f"a {kind} clause names no pattern",
                        "add the pattern it matches")
        # Every pattern, not only the ones whose kind is literally "regex".
        # A plist_value or build_setting pattern is matched with the same engine.
        if clause.get("pattern"):
            try:
                re.compile(clause["pattern"])
            except re.error as exc:
                report.fail("unclear", f"{where} clause {i}",
                            f"pattern does not compile — {exc}",
                            "a pattern that does not compile is a rule that can never fire")


def check_guidelines(rules, index, report):
    cited = 0
    anchorless = []
    for rule, where in rules:
        number = rule.get("guideline")
        if number is None:
            anchorless.append(rule["id"])
            continue
        cited += 1
        entry = index.get(number)
        if entry is None:
            # A parenthetical sub-clause resolves against its parent number,
            # because Apple writes 3.1.1(a) inside 3.1.1 rather than as its own
            # numbered clause.
            entry = index.get(re.sub(r"\([a-z]+\)$", "", number))
        if entry is None:
            report.fail(
                "wrong-citation", where,
                f"guideline {number} does not resolve against Apple's text",
                "cite a number the text defines, or set it to null and record why",
            )
        elif entry["omitted"]:
            report.fail(
                "wrong-citation", where,
                f"guideline {number} resolves but is marked intentionally omitted",
                "Apple reuses and retires numbers; cite the clause that carries the content today",
            )
    return cited, anchorless


def check_guidance(all_rules, report):
    """A `guidance` slug pointing at a section nobody wrote is a rule whose
    subagent improvises, which is how false positives appear."""
    resolved = 0
    headings = {}
    for category in CATEGORIES:
        ref = os.path.join(PLUGIN, "skills", "appstore-audit", "references",
                           f"detection-{category}.md")
        if os.path.exists(ref):
            with open(ref, encoding="utf-8") as fh:
                headings[category] = set(re.findall(r"^#{2,4} (.+)$", fh.read(), re.M))
    for rule, where in all_rules:
        slug = rule.get("guidance")
        if not slug:
            continue
        stem = os.path.basename(where.split(":")[0])
        category = os.path.splitext(stem)[0]
        available = headings.get(category)
        if available is None:
            report.fail("not-actionable", where,
                        f"no detection reference exists for category {category}",
                        f"write skills/appstore-audit/references/detection-{category}.md")
            continue
        # A heading may cover several rules, listed on one line separated by ·
        if any(slug == h or slug in [p.strip() for p in h.split("·")] for h in available):
            resolved += 1
        else:
            report.fail("not-actionable", where,
                        f"guidance slug {slug!r} has no section in detection-{category}.md",
                        "every rule's detection prose must exist at the point the rule is evaluated")
    return resolved


def main(argv):
    targets = argv[1:] or [os.path.join(PLUGIN, "rules", f"{c}.json") for c in CATEGORIES]
    report = Report()
    all_rules = []
    seen = {}

    for path in targets:
        # relpath against the plugin gives ../../.. for anything outside it,
        # which is what a fixture in a temp directory always is.
        inside = os.path.abspath(path).startswith(PLUGIN + os.sep)
        name = os.path.relpath(path, PLUGIN) if inside else os.path.basename(path)
        if not os.path.exists(path):
            report.fail("missing-rule", name, "catalogue file does not exist")
            continue
        try:
            with open(path, encoding="utf-8") as fh:
                doc = json.load(fh)
        except json.JSONDecodeError as exc:
            report.fail("unclear", name, f"not valid JSON — {exc}")
            continue

        problems = check_object(doc, FILE, "$", [])
        if problems:
            for problem in problems:
                report.fail("unclear", name, problem, "the rule record shape is the contract")
            continue

        expected = os.path.splitext(os.path.basename(path))[0]
        if doc["category"] != expected:
            report.fail("contradiction", name,
                        f"declares category {doc['category']} in {expected}.json")
        for rule in doc["rules"]:
            where = f"{name}:{rule['id']}"
            if rule["id"] in seen:
                report.fail("contradiction", where,
                            f"duplicate rule id, also in {seen[rule['id']]}",
                            "rule ids are the key findings reference; they must be unique across categories")
            seen[rule["id"]] = name
            check_rule_semantics(rule, where, report)
            all_rules.append((rule, where))

    if not all_rules:
        # Only a real emptiness, not the shadow of a shape failure already
        # reported above — a second failure for one cause reads as two defects.
        if not report.failures:
            report.fail("missing-rule", "rules/", "no rules were loaded")
        return report.render()

    resolved = check_guidance(all_rules, report)
    report.note(f"{len(all_rules)} rule(s) across {len(targets)} categor(ies) match the rule record shape")
    report.note(f"{len(seen)} rule id(s), all unique")
    report.note(f"{resolved} guidance slug(s) resolve to a section in the detection references")

    # Everything above needs no guideline text. Only citation resolution does —
    # so when the text is absent that one layer is SKIPPED and said to be
    # skipped, rather than failing the whole gate. Apple's text is not vendored:
    # the audit retrieves it in Phase 1 and points this at what it got, which is
    # the only copy that can be current.
    text_path = os.environ.get("APPSTORE_GUIDELINE_TEXT")
    if not text_path:
        report.skip("guideline citations NOT verified — no Apple text supplied",
                    "set APPSTORE_GUIDELINE_TEXT to the text retrieved from Apple to check citations")
        return report.render()
    if not os.path.exists(text_path):
        # Being pointed at a text that is not there IS an error: someone asked
        # for verification and did not get it.
        report.fail("outdated", "guideline anchor", f"cannot read {text_path}",
                    "APPSTORE_GUIDELINE_TEXT must name a readable copy of Apple's guideline text")
        return report.render()

    with open(text_path, encoding="utf-8") as fh:
        index = build_index(fh.read())
    if not index:
        report.fail("outdated", "guideline anchor",
                    f"no guideline numbers could be parsed out of {text_path}",
                    "the retrieved text must be the guidelines page, with its numbered clauses intact")
        return report.render()

    cited, anchorless = check_guidelines(all_rules, index, report)
    report.note(f"{cited} guideline citation(s) checked against {text_path} ({len(index)} numbers defined)")
    cases = sum(len(r.get("cases", [])) for r, _ in all_rules)
    report.note(f"{cases} rejection case(s), every one carrying a source URL")
    conflicts = sum(1 for r, _ in all_rules if r.get("statements"))
    report.note(f"{conflicts} rule(s) record a source conflict rather than collapsing it")
    if anchorless:
        report.note(
            f"{len(anchorless)} rule(s) carry no Apple anchor — permitted, and counted so the number cannot creep: "
            + ", ".join(anchorless)
        )
    return report.render()


if __name__ == "__main__":
    bad = main(sys.argv)
    print()
    print(f"{bad} PROBLEM(S) — a rule does not enter the catalogue until this is clean"
          if bad else "CATALOGUE OK")
    sys.exit(1 if bad else 0)
