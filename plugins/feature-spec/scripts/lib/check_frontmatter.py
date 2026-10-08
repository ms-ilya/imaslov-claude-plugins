# ABOUTME: Validates each SKILL.md's YAML frontmatter against Anthropic's skill-authoring rules.
#
# Malformed frontmatter does not fail loudly. Claude Code loads the skill body
# with EMPTY metadata, so the skill still runs while its description silently
# vanishes — and a single unquoted colon in a description is enough to cause it.
# That is a defect you cannot see by reading the file.
#
# Rules from "The Complete Guide to Building Skills for Claude":
#   - name is kebab-case and should match the folder name
#   - description must say what the skill does AND when to use it. Who reads
#     it depends on the skill: the model, as the trigger, or, when the skill sets
#     disable-model-invocation, only the person choosing from the `/` menu.
#   - description under 1024 characters, no angle brackets. Only the description
#     of a model-invocable skill enters the system prompt, but skill-creator's
#     quick_validate.py rejects both for every skill.
#   - SKILL.md body under 5,000 words; move detail into references/

import glob
import json
import os
import re
import shutil
import subprocess
import sys

# Exit status when no YAML parser is available. The caller reports the group as
# skipped; a check that did not run must not be counted as one that passed.
SKIPPED = 3

KEBAB = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$')


def load_yaml(text):
    """Parse with pyyaml, or with the Ruby that macOS ships when pyyaml is
    absent. Raises LookupError when neither is there."""
    try:
        import yaml
    except ImportError:
        yaml = None
    if yaml is not None:
        return yaml.safe_load(text)
    if not shutil.which('ruby'):
        raise LookupError("no YAML parser: install pyyaml, or have ruby on PATH")
    run = subprocess.run(['ruby', '-ryaml', '-rjson', '-e',
                          'puts JSON.generate(YAML.safe_load(STDIN.read))'],
                         input=text, capture_output=True, text=True)
    if run.returncode != 0:
        raise ValueError((run.stderr.strip().splitlines() or ['could not be parsed'])[-1])
    return json.loads(run.stdout)


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
            meta = load_yaml(m.group(1))
        except LookupError as exc:
            print(f"skip  frontmatter checks ({exc})")
            sys.exit(SKIPPED)
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
             "remove < and > — skill validators reject them in a description"),
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
