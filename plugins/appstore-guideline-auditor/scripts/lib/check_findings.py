# ABOUTME: Checks a subagent's findings against the catalogue they claim to come from — the rule exists, and its guideline and severity are the catalogue's.
#
# The schema says what a finding must LOOK like. It cannot say whether the
# finding is about a rule that exists, because the schema does not have the
# catalogue. So a document naming rule "totally-invented-rule-id" at guideline
# "7.9.9(z)" — a section Apple does not have — passed validation cleanly, and so
# did a real rule cited at the wrong number and a softened severity.
#
# The contract's two rules about invention are R2, never emit a finding for a
# rule not in the catalogue, and R3, never state a guideline number a rule does
# not carry. Both were enforced by instruction only. An instruction is a request
# made of a language model; this is the check that makes them facts.
#
# Severity is included because the agent card already says "Severity comes from
# the rule and you do not change it". A claim stated in prose and enforced
# nowhere is a claim that holds until the first run that ignores it.

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.dirname(os.path.dirname(HERE))
CATEGORIES = ["safety", "performance", "business", "design", "legal"]


def load_catalogue(rules_dir):
    """Maps rule id -> the fields a finding is not allowed to restate wrongly."""
    catalogue = {}
    for category in CATEGORIES:
        path = os.path.join(rules_dir, f"{category}.json")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as fh:
            doc = json.load(fh)
        for rule in doc.get("rules", []):
            catalogue[rule["id"]] = {
                "category": doc.get("category"),
                "guideline": rule.get("guideline"),
                "severity": rule["severity"],
                "verifiability": rule["verifiability"],
            }
    return catalogue


def check_item(item, record, where, kind, problems):
    if record is None:
        problems.append(
            f"{where}: rule {item.get('rule')!r} is not in the catalogue — R2 forbids "
            "emitting a finding for a rule that has not passed the entry gate"
        )
        return

    if item.get("guideline") != record["guideline"]:
        problems.append(
            f"{where}: cites guideline {item.get('guideline')!r}, but the catalogue records "
            f"{record['guideline']!r} for this rule — R3 forbids restating it"
        )
    if item.get("severity") != record["severity"]:
        problems.append(
            f"{where}: states severity {item.get('severity')!r}, but the catalogue records "
            f"{record['severity']!r} — severity comes from the rule and is not the agent's to change"
        )

    # Verifiability is a ceiling, not an equality: a PROVEN rule may yield a
    # PROBABLE finding. What it may never do is grade above the ceiling, or
    # emit a MANUAL rule as a finding at all.
    ceiling = record["verifiability"]
    if kind == "finding":
        if ceiling == "MANUAL":
            problems.append(
                f"{where}: rule is MANUAL in the catalogue, so it produces a checklist item, "
                "never a finding"
            )
        elif ceiling == "PROBABLE" and item.get("verifiability") == "PROVEN":
            problems.append(
                f"{where}: graded PROVEN, but the catalogue caps this rule at PROBABLE"
            )
    elif ceiling != "MANUAL":
        problems.append(
            f"{where}: appears as a checklist item, but the catalogue grades this rule "
            f"{ceiling} — a rule code can decide belongs in the findings"
        )


def check_file(path, catalogue):
    problems = []
    with open(path, encoding="utf-8") as fh:
        doc = json.load(fh)

    name = os.path.basename(path)
    category = doc.get("category")
    for kind, key in (("finding", "findings"), ("checklist item", "checklist")):
        for i, item in enumerate(doc.get(key, [])):
            where = f"{name} {key}[{i}]"
            record = catalogue.get(item.get("rule"))
            check_item(item, record, where, kind, problems)
            # A category subagent reporting another category's rule means the
            # fan-out overlapped, and the same finding will arrive twice.
            if record is not None and category and record["category"] != category:
                problems.append(
                    f"{where}: rule belongs to category {record['category']!r}, but this file "
                    f"reports category {category!r}"
                )
    return problems


def main(argv):
    if len(argv) < 2:
        print("usage: check_findings.py <findings.json> [rules-dir]", file=sys.stderr)
        return 2
    rules_dir = argv[2] if len(argv) > 2 else os.path.join(PLUGIN, "rules")
    catalogue = load_catalogue(rules_dir)
    if not catalogue:
        print(f"      no catalogue could be loaded from {rules_dir}")
        return 1
    problems = check_file(argv[1], catalogue)
    for problem in problems:
        print(f"      {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
