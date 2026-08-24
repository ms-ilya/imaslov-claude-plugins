# ABOUTME: Validates each SKILL.md's YAML frontmatter against Anthropic's skill-authoring rules.
#
# Malformed frontmatter does not fail loudly. Claude Code loads the skill body
# with EMPTY metadata, so the skill still runs while its description silently
# vanishes — and a single unquoted colon in a description is enough to cause it.
# That is a defect you cannot see by reading the file.
#
# Rules from "The Complete Guide to Building Skills for Claude":
#   - name is kebab-case and should match the folder name
#   - description must say what the skill does AND when to use it
#   - description under 1024 characters, no angle brackets (it enters the system prompt)
#   - SKILL.md body under 5,000 words; move detail into references/

import glob
import os
import re
import sys

try:
    import yaml
except ImportError:
    print("skip  frontmatter checks (pyyaml not installed)")
    sys.exit(0)

KEBAB = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$')


def check(skills_dir):
    bad = 0
    for path in sorted(glob.glob(os.path.join(skills_dir, '*', 'SKILL.md'))):
        folder = os.path.basename(os.path.dirname(path))
        text = open(path).read()

        m = re.match(r'^---\n(.*?)\n---', text, re.S)
        if not m:
            print(f"FAIL  {folder}: no frontmatter block")
            print("      expected: --- ... --- at the very top of the file")
            bad += 1
            continue
        try:
            meta = yaml.safe_load(m.group(1))
        except Exception as exc:
            print(f"FAIL  {folder}: frontmatter is not valid YAML — {str(exc).splitlines()[0]}")
            print('      expected: quote any value containing a colon, e.g. description: "a: b"')
            bad += 1
            continue
        if not isinstance(meta, dict):
            print(f"FAIL  {folder}: frontmatter did not parse to a mapping")
            bad += 1
            continue

        name = meta.get('name', '')
        desc = meta.get('description', '') or ''
        words = len(text.split())

        rules = [
            ("name matches the folder", name == folder, f"name: {folder}"),
            ("name is kebab-case", bool(KEBAB.match(str(name))), "lower case, hyphens only"),
            ("description present", bool(desc), "description: <what it does>. Use when <trigger>."),
            ("description under 1024 chars", len(desc) < 1024, f"trim from {len(desc)}"),
            ("description says WHEN to use it", any(k in desc.lower() for k in ('use when', 'use for')),
             "append: Use when <trigger condition>."),
            ("no angle brackets in description", '<' not in desc and '>' not in desc,
             "remove < and > — frontmatter is injected into the system prompt"),
            ("body under 5000 words", words < 5000, f"{words} words — move detail into references/"),
        ]
        failed = [(label, fix) for label, cond, fix in rules if not cond]
        for label, fix in failed:
            print(f"FAIL  {folder}: {label}")
            print(f"      expected: {fix}")
            bad += 1
        if not failed:
            print(f"ok    {folder}: frontmatter valid, {words} words, description {len(desc)} chars")
    return bad


if __name__ == '__main__':
    sys.exit(1 if check(sys.argv[1]) else 0)
