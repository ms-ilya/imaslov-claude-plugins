#!/usr/bin/env bash
# ABOUTME: Entry gate for the rule catalogue — validates rule records, their guideline citations and their rejection cases.
#
# Usage: check-catalogue.sh [--guideline-text <path>] [rules/*.json ...]
# With no rule files it checks every shipped category file.
#
# Without --guideline-text it checks only what needs no network: record shape,
# unique ids, patterns that compile, guidance slugs that resolve to prose that
# exists. Citation resolution is SKIPPED and says so.
#
# Pass --guideline-text with the text an audit retrieved from Apple to add that
# layer: every cited number must exist in the text and not be marked
# intentionally omitted. No snapshot is vendored: a copy pinned at release
# cannot reach a clause renumbered afterwards, and a stale anchor is worse than
# a missing one because it makes a drifted citation look verified.
#
# The text is an argument, not an environment variable, because the skill's
# permission rule matches the command from its first word: a leading VAR=value
# assignment puts the command outside the rule and prompts mid-audit.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v python3 >/dev/null 2>&1 || {
  echo "check-catalogue: python3 not found — cannot validate" >&2
  exit 1
}

exec python3 "$HERE/lib/check_catalogue.py" "$@"
