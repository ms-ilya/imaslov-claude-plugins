---
description: Audit a native iOS project for App Store rejection risks, read-only, with dual-graded findings.
---

# App Store Guideline Audit

Audit a native iOS Xcode project against the App Store Review Guidelines. Every
finding carries two independent grades — a severity, and how firmly code
evidence supports it — and everything the code cannot decide goes to an App
Store Connect checklist instead of being guessed at.

The audit is read-only with respect to the project: it modifies nothing that was
already there, and creates exactly one file, its report.

## Read the skill first

Before doing anything, read `SKILL.md` from the `appstore-audit` skill in the
appstore-guideline-auditor plugin, and follow it exactly.

## Action

Run phases 0 through 5 from that SKILL.md.

**Arguments:** `$ARGUMENTS` — the project path, and optionally `--out <path>`
for the report.
