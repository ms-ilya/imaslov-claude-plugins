---
name: memory-bank
description: >-
  Maintain a living documentation system ("Memory Bank") that captures the current state of a
  project, organized by feature. Use this skill whenever the user mentions "memory bank",
  "memory-bank", or asks to document a feature, update feature docs, or refresh project
  documentation. Also trigger when the user says things like "document feature X", "what's
  the state of feature X", "update docs for feature X", or "create context for feature X".
  This skill is about maintaining a living snapshot of the codebase — not changelogs or git
  history. Optimized for Swift/iOS/macOS projects but works on any codebase. For explicit
  commands, prefer the dedicated sub-skills: update-memory-bank, init-memory-bank,
  update-memory-bank-system, add-decision.
tools: Read, Write, Edit, Glob, Bash
---

# Memory Bank — Living Project Documentation

## Purpose

The Memory Bank is a structured documentation system that captures **what is true right now**
about a project, organized by feature. It gives an AI agent (or a new developer) the fastest
possible path to understanding any feature: how it works, what's in progress, what decisions
were made, and what to watch out for.

**This is NOT a changelog.** Git tracks history. The Memory Bank tracks current state.

## Core Principles

1. **Current state only** — every file describes what is true right now. No date-stamped entries, no "on Jan 5 we changed X."
2. **Feature-centric** — each feature gets its own folder with a consistent file set.
3. **Fast context loading** — read WIKI.md → pick a feature → be productive immediately.
4. **Anti-hallucination** — every file path, type name, and behavioral claim gets verified against actual source code. Unverifiable claims are flagged or omitted.
5. **Mostly agnostic, Swift-optimized** — works on any codebase, but understands Swift/Xcode conventions deeply.

---

## Memory Bank Structure

```
memory-bank/
├── WIKI.md                          # Navigation hub — read this first
├── systemPatterns.md                # Architecture, patterns, conventions
├── techContext.md                   # Stack, deps, build setup, tooling
├── TROUBLESHOOTING.md               # Project-wide issues + links to per-feature ones
│
├── <feature-name>/
│   ├── IMPLEMENTATION.md            # How the feature works
│   ├── ACTIVE_CONTEXT.md            # Current state + in-progress work
│   ├── DECISIONS.md                 # Key decisions (ADR-style, user-curated only)
│   └── TROUBLESHOOTING.md           # Feature-specific gotchas
```

---

## Workflow Routing

Determine which workflow to run based on the user's request:

| User says | Workflow |
|-----------|----------|
| `update memory-bank for feature X` / `document feature X` | **Feature Update** (primary) |
| `create memory-bank` / `initialize memory-bank` | **Initialize** |
| `update memory-bank system` / `refresh system docs` | **System Update** |
| `add decision for feature X: ...` | **Manual Decision** — append to feature's DECISIONS.md |

If `memory-bank/` does not exist at the project root when any workflow triggers, run **Initialize** first, then continue with the requested workflow.

---

## Workflow 1: Feature Update (Primary)

This is the main workflow. Triggered by: `update memory-bank for feature X`

### Step 1 — Locate project root and memory-bank

Find the project root by looking for markers: `.git/`, `Package.swift`, `*.xcodeproj`, `*.xcworkspace`, `Podfile`, `Cargo.toml`, `package.json`, etc. If uncertain, ask the user.

Check if `memory-bank/` exists at root. If not, run Initialize first.

### Step 2 — Feature discovery

Find all files related to feature X using keyword/grep scanning:

```bash
# Generate search variations: original, camelCase, PascalCase, snake_case, kebab-case
# Example for "user profile": userProfile, UserProfile, user_profile, user-profile

# Search across the project (exclude build artifacts, dependencies, memory-bank itself)
grep -rl --include="*.swift" --include="*.xib" --include="*.storyboard" \
  --include="*.plist" --include="*.xcconfig" --include="*.entitlements" \
  --include="*.json" --include="*.yaml" --include="*.yml" \
  --exclude-dir=DerivedData --exclude-dir=.build --exclude-dir=Pods \
  --exclude-dir=node_modules --exclude-dir=Carthage --exclude-dir=memory-bank \
  --exclude-dir=.git \
  "<search-term>" .

# Also search file and directory names
find . -type f \( -name "*<search-term>*" \) \
  -not -path "*/DerivedData/*" -not -path "*/.build/*" \
  -not -path "*/Pods/*" -not -path "*/memory-bank/*" -not -path "*/.git/*"
```

**Swift-specific discovery additions:**
- Search `.xcassets` for feature-related asset catalogs
- Check `.storyboard` and `.xib` for view controller references
- Look for protocol conformances: `grep -r "protocol.*<FeatureName>" --include="*.swift"`
- Check target membership if `.xcodeproj` exists

**Cap results at 30 files.** If more than 30 matches, rank by relevance:
1. Files with the feature name IN the filename (highest)
2. Files with the feature name in a class/struct/protocol declaration
3. Files that import/reference feature-related types
4. Files with the feature name only in comments or strings (lowest)

Show the top 30 to the user and mention additional matches count. Ask: **"Does this file list look right? Anything to add or remove?"** Wait for confirmation before proceeding.

### Step 3 — Deep analysis

Read all confirmed files. Extract:
- **Architecture:** Entry points, data flow, key types (protocols, classes, structs, enums)
- **Dependencies:** What this feature imports/calls from other modules or features
- **External deps:** Third-party libraries this feature uses
- **UI layer:** Views, view models, view controllers, SwiftUI views
- **State management:** How state flows (Combine, async/await, delegates, closures, TCA)
- **Patterns:** Unusual code, workarounds, TODOs, FIXMEs, HACKs
- **Tests:** Related test files and what they cover

### Step 4 — Check existing documentation

If `memory-bank/<feature-name>/` exists → **Update mode:**
1. Read all four existing files
2. Compare documented state against current code analysis
3. Identify: new files not documented, removed files still documented, changed types/patterns, stale descriptions
4. Preserve content that is still accurate
5. Update what has changed
6. Remove what no longer exists (do not leave stale references)

If folder does not exist → **Creation mode:** Generate all four files from scratch.

### Step 5 — Write the four feature files

Read `references/templates.md` for the exact format of each file. Write:
1. **IMPLEMENTATION.md** — from deep analysis
2. **ACTIVE_CONTEXT.md** — from current code state + ask user about in-progress work if unclear
3. **DECISIONS.md** — empty template (user-curated only; never auto-populate)
4. **TROUBLESHOOTING.md** — from TODOs, FIXMEs, compiler warnings, known patterns

### Step 6 — Verification pass (MANDATORY)

This step is non-negotiable. Read `references/verification.md` for the full procedure.

Summary:
- Every file path in docs → `test -f <path>` to confirm existence
- Every type name (class, struct, protocol, enum) → `grep` to confirm it exists in `.swift` files
- Every described behavior → trace to an actual function/method in the source
- Anything unverifiable → mark with `⚠️ UNVERIFIED` or remove entirely
- Never invent file paths. If a file can't be found, say "file not found" in the doc.

### Step 7 — Update root-level files

- **WIKI.md** — add or update the feature entry in the index table
- **TROUBLESHOOTING.md** (root) — update the feature link; add any cross-cutting issues found
- **systemPatterns.md** — update if new architectural patterns were discovered
- **techContext.md** — update if new dependencies or build configurations were found

---

## Workflow 2: Initialize

Triggered by: `create memory-bank` / `initialize memory-bank`, or auto-triggered when `memory-bank/` doesn't exist.

### Steps:

1. **Scan the project** for: tech stack, architecture, module/target structure, dependencies, build setup
2. **Create `memory-bank/`** directory at project root
3. **Write root-level files:**
   - `WIKI.md` — project overview + empty features table + "How to use" section
   - `systemPatterns.md` — architecture, patterns, conventions discovered
   - `techContext.md` — stack, deps, build setup, tooling
   - `TROUBLESHOOTING.md` — any project-wide issues found (or empty template)
4. **Run verification pass** on root files
5. Inform the user the Memory Bank is ready and they can start documenting features

---

## Workflow 3: System Update

Triggered by: `update memory-bank system` / `refresh system docs`

### Steps:

1. Re-analyze project-wide: architecture, dependencies, patterns, build setup
2. Update `systemPatterns.md` and `techContext.md`
3. Re-scan all feature folders in `memory-bank/` and rebuild `WIKI.md` index
4. Update root `TROUBLESHOOTING.md` — refresh links, add new cross-cutting issues
5. Run verification pass on root files

---

## Workflow 4: Manual Decision

Triggered by: `add decision for feature X: <description>`

### Steps:

1. Open `memory-bank/<feature-name>/DECISIONS.md`
2. Add a new decision entry using the ADR template (see `references/templates.md`)
3. Ask the user for: rationale, alternatives considered, consequences (if not provided)
4. Append to the file (decisions are cumulative, never overwrite)

---

## Swift-Specific Intelligence

When working with Swift projects, the skill understands:

| Area | What to look for |
|------|-----------------|
| **Project files** | `.xcodeproj`, `.xcworkspace`, `Package.swift`, `Podfile`, `Cartfile` |
| **Source files** | `.swift`, `.xib`, `.storyboard`, `.xcassets`, `.xcconfig`, `.entitlements`, `Info.plist` |
| **Patterns** | SwiftUI views, UIKit view controllers, Combine publishers, async/await, protocol extensions, property wrappers, result builders, actors |
| **Architecture** | MVVM, MVC, Clean/VIPER, Coordinator, TCA (The Composable Architecture) |
| **DI patterns** | Protocol-based DI, Environment values (SwiftUI), `@Injected` wrappers, factory patterns |
| **Module structure** | Targets, frameworks, SPM packages, feature modules |
| **Build system** | Schemes, configurations, build phases, run scripts, `.xcconfig` files |
| **Ignore always** | `DerivedData/`, `.build/`, `Pods/`, `*.generated.swift`, `*.pbxproj` (binary), build caches |

When describing types in IMPLEMENTATION.md, note:
- Protocol conformances (what protocols a type adopts)
- Property wrappers in use (`@Published`, `@State`, `@Binding`, `@EnvironmentObject`, etc.)
- Concurrency model (MainActor, Sendable, async/await, Combine)
- Whether it's iOS-only, macOS-only, or cross-platform

---

## Edge Case Handling

| Situation | Response |
|-----------|----------|
| **Feature spans 50+ files** | Group by sub-concern (Networking, UI, Storage, etc.) in IMPLEMENTATION.md. List top files per group, link to directories for the rest. |
| **Feature is tiny (1-3 files)** | Still create all four files. Consistency matters. They'll just be short. |
| **Feature name is ambiguous / zero results** | Ask the user to clarify. Suggest alternative search terms. Never proceed with zero files. |
| **Existing docs are stale** | Update mode handles this: identify removed files/types, flag stale descriptions, update or remove. |
| **Conflicting information in code** | Flag with `⚠️ CONFLICT` and describe both versions. Let the user resolve. |
| **Memory bank exists but different structure** | Migrate to expected structure. Preserve existing content. Inform user of changes made. |
| **Circular cross-feature dependencies** | Document in both features' IMPLEMENTATION.md cross-reference sections. |
| **Test files discovered** | Include under a "Testing" section in IMPLEMENTATION.md. |
| **Feature name collides with common keyword** | Ask user for 2-3 distinguishing terms to narrow the search. |

---

## Anti-Hallucination Rules

These are hard rules. Never violate them:

1. **Verify every file path** before writing it in any doc. Use `test -f <path>`.
2. **Verify every type name** with `grep -r "class\|struct\|protocol\|enum" --include="*.swift"`.
3. **Never invent file paths.** If a file can't be found, write "file not found" — never guess.
4. **Never assume behavior.** If code is ambiguous, write what's visible + flag "needs clarification."
5. **Cap speculation.** If you must describe inferred behavior, prefix with "Appears to..." and mark `⚠️ INFERRED`.
6. **User confirmation on discovery.** Always show the discovered file list and wait for confirmation.
7. **Timestamp every file.** Include `<!-- Last verified: YYYY-MM-DD -->` at the top of every generated file.

---

## Sub-Skills

This plugin includes dedicated sub-skills for each workflow:

| Sub-Skill | Purpose |
|-----------|---------|
| `update-memory-bank` | Document or update a feature (primary workflow) |
| `init-memory-bank` | Initialize memory bank for a new project |
| `update-memory-bank-system` | Refresh root-level docs only |
| `add-decision` | Record a technical decision |

---

## Reference Files

Read these before writing docs:

| Reference | When to read | Path |
|-----------|-------------|------|
| **Templates** | Before writing any memory-bank file | `references/templates.md` |
| **Verification** | During Step 6 of Feature Update | `references/verification.md` |
