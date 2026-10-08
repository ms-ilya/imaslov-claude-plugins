#!/bin/bash
# ABOUTME: Prints the critical and warning findings that have no verdict yet, one JSON object per line, for the finding-verifier agents.

set -euo pipefail

DIR=".ios-review-temp"

shopt -s nullglob
FINDING_FILES=("$DIR"/review-*.json "$DIR"/*-analysis.json)
VERDICT_FILES=("$DIR"/verdicts-*.json)

# An agent that was cut off can leave a file that is not valid JSON. It is
# skipped here with a note on stderr, and build-report.sh names it in the report.
readable() {
    local file
    for file in "$@"; do
        if jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
            printf '%s\n' "$file"
        else
            echo "findings-worklist: skipped unreadable $(basename "$file")" >&2
        fi
    done
}

FINDINGS=()
while IFS= read -r file; do FINDINGS+=("$file"); done < <(readable ${FINDING_FILES[@]+"${FINDING_FILES[@]}"})
VERDICTS=()
while IFS= read -r file; do VERDICTS+=("$file"); done < <(readable ${VERDICT_FILES[@]+"${VERDICT_FILES[@]}"})

[ ${#FINDINGS[@]} -gt 0 ] || exit 0

JUDGED='[]'
if [ ${#VERDICTS[@]} -gt 0 ]; then
    JUDGED=$(jq -s '[.[] | .verdicts // [] | .[].id]' "${VERDICTS[@]}")
fi

# The id is the findings file name plus the finding's position in it. A verifier
# copies the id back verbatim, so a verdict joins to its finding without a model
# having to count array positions. Suggestions are left out: re-reading code to
# confirm a style nit costs more than a wrong one does.
jq -c --argjson judged "$JUDGED" '
    (input_filename | sub(".*/"; "")) as $source
    | .findings // []
    | to_entries[]
    | select(.value.severity == "critical" or .value.severity == "warning")
    | {id: "\($source)#\(.key)"} + (.value | {severity, file, line, category, issue, evidence})
    | select(.id as $id | $judged | index($id) | not)
' "${FINDINGS[@]}"
