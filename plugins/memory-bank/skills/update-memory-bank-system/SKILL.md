---
name: update-memory-bank-system
description: >-
  Refresh Memory Bank root-level documentation (systemPatterns.md, techContext.md,
  WIKI.md index, TROUBLESHOOTING.md). Does not touch individual feature docs.
  Use this skill when the user says "refresh system docs", "update memory-bank system",
  "update root docs", "refresh memory-bank", or "rebuild wiki index".
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Update Memory Bank System Docs

You are refreshing the project-wide Memory Bank documentation — the root-level files that describe architecture, tech stack, and the feature index.

---

## Pre-Flight

1. Find the project root
2. If `memory-bank/` doesn't exist → tell the user to run `/init-memory-bank` first
3. Detect project language by checking for config files at the root (use `Glob`):
   Swift (`Package.swift`, `*.xcodeproj`) · TypeScript (`tsconfig.json`) · Python (`pyproject.toml`, `setup.py`) · Rust (`Cargo.toml`) · Go (`go.mod`) · Kotlin (`build.gradle.kts`) · Java (`pom.xml`, `build.gradle`)
   Use the detected language's file extensions for all subsequent searches. If a language-specific reference exists (e.g., `../memory-bank/references/swift-intelligence.md` for Swift/iOS), read it

Note: Read templates from `../memory-bank/references/templates.md` just before writing each file — only the section you need, not the whole file.

## Step 1 — Re-Analyze Project

Scan the project for current state:
- Architecture, design patterns, module structure
- Dependencies and versions (read package manifest files)
- Build setup, CI/CD configuration
- Any new cross-cutting patterns since last update

Use `Glob` and `Grep` tools for all discovery.

## Step 2 — Update Root Files (One at a Time)

Update each file, then verify immediately:

1. **systemPatterns.md** — update architecture, patterns, conventions
2. **techContext.md** — update stack, deps, build setup
3. **WIKI.md** — re-scan all feature folders in `memory-bank/` and rebuild the feature index table
4. **TROUBLESHOOTING.md** (root) — refresh feature links, add new cross-cutting issues

## Step 3 — Verify Each File (MANDATORY)

Read `../memory-bank/references/verification.md` for the procedure. After each file:

1. Verify every file path using `Glob`
2. Verify every type/module name using `Grep`
3. Flag unverifiable content or remove it

**Output a verification summary** after each file.

## Key Rules

- This does NOT update individual feature docs — use `/update-memory-bank <feature>` for that
- **Current state only** — no changelogs
- **Every path and type must be verified**
- **Use Grep/Glob tools** for all searches
