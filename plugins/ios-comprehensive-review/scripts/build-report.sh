#!/bin/bash
# ABOUTME: Merges the analyzers' findings and the verifiers' verdicts into the final markdown review report.

set -euo pipefail

DIR=".ios-review-temp"
CONTEXT="$DIR/pr-context.json"
REPORT="$DIR/ios-review-report.md"

if [ ! -f "$CONTEXT" ]; then
    echo "build-report: $CONTEXT not found. Run the extract stage first." >&2
    exit 1
fi

shopt -s nullglob
FINDING_FILES=("$DIR"/review-*.json "$DIR"/*-analysis.json)
VERDICT_FILES=("$DIR"/verdicts-*.json)

# An agent that was cut off can leave a file that is not valid JSON. Such a file
# is named in the report instead of failing the build: the rest of the review is
# still worth reading, and a review that hides a file it could not read looks
# like a clean one.
READABLE=()
UNREADABLE=()
for file in ${FINDING_FILES[@]+"${FINDING_FILES[@]}"} ${VERDICT_FILES[@]+"${VERDICT_FILES[@]}"}; do
    if jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
        READABLE+=("$file")
    else
        UNREADABLE+=("$(basename "$file")")
    fi
done

UNREADABLE_JSON='[]'
if [ ${#UNREADABLE[@]} -gt 0 ]; then
    UNREADABLE_JSON=$(printf '%s\n' "${UNREADABLE[@]}" | jq -R . | jq -s .)
fi

# Verdicts decide what is shown. "refuted" moves a finding to its own section,
# "confirmed" shows it as is, and a critical or warning finding with any other
# verdict, or none, is shown marked unverified. Nothing is dropped silently.
#
# The report and the one-line summary come out of one pass as one object, so the
# counts printed to the terminal cannot disagree with the counts in the file.
RESULT=$(jq -n \
    --slurpfile context "$CONTEXT" \
    --argjson unreadable "$UNREADABLE_JSON" '
    def blockquote: split("\n") | map("> " + .) | join("\n");

    def render:
        "### \(.category)\n"
        + "**File:** `\(.file):\(.line)` | **Agent:** \(.agent)\n\n"
        + .issue + (if .unverified then " (unverified)" else "" end) + "\n\n"
        + "> **Evidence:**\n"
        + (if (.evidence // "") == "" then "> No code evidence provided" else (.evidence | blockquote) end)
        + (if (.fix // "") == "" then "" else "\n\n**Fix:** \(.fix)" end)
        + "\n\n---\n";

    def section($title; $items):
        if ($items | length) == 0 then ""
        else "## \($title)\n\n" + ($items | map(render) | join("\n")) + "\n" end;

    $context[0] as $pr
    | [inputs | {source: (input_filename | sub(".*/"; "")), doc: .}] as $files
    | ([$files[] | .doc.verdicts // [] | .[] | {key: .id, value: .}] | from_entries) as $verdicts
    | [ $files[]
        | .source as $source
        | (.doc.agent // "unknown") as $agent
        | .doc.findings // []
        | to_entries[]
        | .value + {id: "\($source)#\(.key)", agent: $agent}
      ]
    | unique_by([.file, .line, .issue, .agent])
    | map(. + {verdict: ($verdicts[.id].verdict // "none"), reason: ($verdicts[.id].reason // "")})
    | map(. + {unverified: (.severity != "suggestion" and .verdict != "confirmed" and .verdict != "refuted")}) as $all
    | ($all | map(select(.verdict == "refuted"))) as $dropped
    | ($all | map(select(.verdict != "refuted"))) as $kept
    | ($kept | map(select(.severity == "critical"))) as $critical
    | ($kept | map(select(.severity == "warning"))) as $warning
    | ($kept | map(select(.severity == "suggestion"))) as $suggestion
    | ($kept | map(select(.unverified)) | length) as $unverified
    | ([$pr.changed_files[] | select(.change_type != "deleted")] | length) as $expected
    | ([$files[] | select(.source | startswith("review-"))] | length) as $reviewed
    | {
        report: (
            (if $pr.pr_number > 0 then "# iOS Review: #\($pr.pr_number) - \($pr.title)" else "# iOS Review: \($pr.title)" end) + "\n\n"
            + "**Author:** \($pr.author) | **Branch:** \($pr.head_branch) → \($pr.base_branch) | **Files:** \($pr.changed_files | length)\n\n"
            + "## Summary\n\n"
            + "| Severity | Count |\n|----------|-------|\n"
            + "| Critical | \($critical | length) |\n"
            + "| Warning | \($warning | length) |\n"
            + "| Suggestion | \($suggestion | length) |\n\n"
            + section("Critical Issues"; $critical)
            + section("Warnings"; $warning)
            + section("Suggestions"; $suggestion)
            + (if ($dropped | length) == 0 then ""
               else "## Dropped by verification\n\n"
                    + "A verifier re-read the code and could show these findings were wrong.\n\n"
                    + ($dropped | map("- `\(.file):\(.line)` (\(.agent)) \(.issue)\n  Reason: \(.reason)") | join("\n")) + "\n\n" end)
            + (if ($unreadable | length) == 0 then ""
               else "## Output files that could not be read\n\n"
                    + "These files are not valid JSON, so whatever they held is missing from this report.\n\n"
                    + ($unreadable | map("- `\(.)`") | join("\n")) + "\n\n" end)
            + "## Statistics\n\n"
            + "Files Reviewed: \($reviewed) of \($expected) | Total Findings: \($kept | length)"
            + " | Unverified: \($unverified) | Dropped by verification: \($dropped | length)"
            + " | Agents: \([$kept[].agent] | unique | join(", "))\n"
        ),
        summary: "Critical: \($critical | length) | Warning: \($warning | length) | Suggestion: \($suggestion | length) | Unverified: \($unverified) | Dropped by verification: \($dropped | length) | Files reviewed: \($reviewed) of \($expected) | Unreadable output files: \($unreadable | length)"
      }
' ${READABLE[@]+"${READABLE[@]}"})

jq -r '.report' <<< "$RESULT" > "$REPORT"

echo "Report: $REPORT"
jq -r '.summary' <<< "$RESULT"
