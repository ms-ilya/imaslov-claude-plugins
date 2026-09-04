#!/usr/bin/env bash
# ABOUTME: Entry gate for the rule catalogue — validates rule records, their guideline citations and their rejection cases.
#
# Usage: check-catalogue.sh [rules/*.json ...]
# With no arguments it checks every shipped category file.
#
# Without APPSTORE_GUIDELINE_TEXT it checks only what needs no network: record
# shape, unique ids, patterns that compile, guidance slugs that resolve to prose
# that exists. Citation resolution is SKIPPED and says so.
#
# Point APPSTORE_GUIDELINE_TEXT at the text an audit retrieved from Apple to add
# that layer. No snapshot is vendored: a copy pinned at release cannot reach a
# clause renumbered afterwards, and a stale anchor is worse than a missing one
# because it makes a drifted citation look verified.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v python3 >/dev/null 2>&1 || {
  echo "check-catalogue: python3 not found — cannot validate" >&2
  exit 1
}

exec python3 "$HERE/lib/check_catalogue.py" "$@"
