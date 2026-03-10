# Verification Procedure

This procedure is **mandatory** for every Memory Bank write operation. Never skip it.
Run it after drafting docs but before committing them to the memory-bank.

---

## Overview

The verification pass catches hallucinations before they enter the documentation.
Every claim in a Memory Bank file must be traceable to actual source code.

## Step-by-Step Procedure

### Phase 1: File Path Verification

For every file path mentioned in any Memory Bank document:

```bash
# For each path referenced in docs:
test -f "<project-root>/<path>" && echo "✅ EXISTS" || echo "❌ MISSING: <path>"
```

**If a path fails:**
- Check for typos, case sensitivity (especially on case-sensitive filesystems)
- Search for the file by name: `find . -name "<filename>"`
- If found at a different path → fix the path in docs
- If not found anywhere → remove the reference or mark `⚠️ FILE NOT FOUND`

**Never leave an unverified path in documentation without a flag.**

### Phase 2: Type Name Verification

For every class, struct, protocol, or enum mentioned in docs:

```bash
# Verify type exists
grep -rn "class <TypeName>" --include="*.swift" .
grep -rn "struct <TypeName>" --include="*.swift" .
grep -rn "protocol <TypeName>" --include="*.swift" .
grep -rn "enum <TypeName>" --include="*.swift" .
```

**If a type is not found:**
- Check for typos and naming variations
- It may be defined via typealias — check: `grep -rn "typealias <TypeName>" --include="*.swift"`
- It may be in a dependency (Pods, SPM packages) — note this if so
- If genuinely not found → remove or mark `⚠️ TYPE NOT FOUND`

### Phase 3: Behavioral Claim Verification

For every statement about what code does (e.g., "TokenManager handles OAuth refresh"):

```bash
# Verify the described behavior exists in the claimed file
grep -n "func refresh\|func handleRefresh\|refresh(" "<file-path>"
```

**Levels of confidence:**
- **Verified** (default, no flag needed): Function/method found, behavior matches description
- **⚠️ INFERRED**: Code structure suggests this behavior, but it's not explicit (e.g., a method is called `refresh` but doesn't have documentation confirming it handles OAuth specifically)
- **⚠️ UNVERIFIED**: Cannot trace to actual code — remove the claim or flag it

### Phase 4: Cross-Reference Verification

For every cross-feature dependency mentioned:

```bash
# Verify that feature A actually imports/uses feature B
grep -rn "import <ModuleName>" --include="*.swift" <feature-A-path>/
grep -rn "<TypeFromFeatureB>" --include="*.swift" <feature-A-path>/
```

### Phase 5: Staleness Check (Update Mode Only)

When updating existing docs, check for removed content:

```bash
# For each file path in existing docs
# (parse the markdown tables to extract paths, then verify each)
test -f "<path>" || echo "⚠️ STALE: <path> no longer exists"

# For each type name in existing docs
grep -rn "class\|struct\|protocol\|enum" --include="*.swift" . | grep "<TypeName>" || echo "⚠️ STALE: <TypeName>"
```

**Stale content policy:**
- Removed files → remove from docs entirely (do not leave references to deleted files)
- Renamed files → update the path
- Renamed types → update the type name
- Changed behavior → update the description

---

## Verification Summary Format

After completing verification, mentally confirm:

- Total paths checked: [N]
- Paths verified: [N]
- Paths flagged/removed: [N]
- Types checked: [N]
- Types verified: [N]
- Types flagged/removed: [N]
- Behavioral claims verified: [N]
- Claims flagged as INFERRED: [N]
- Claims removed: [N]

This does NOT need to be written into the docs — it is an internal quality check.

---

## Common Verification Pitfalls

| Pitfall | Prevention |
|---------|------------|
| **Case sensitivity** | macOS is case-insensitive by default, but Linux and CI are not. Always use exact casing from the filesystem. |
| **Generated files** | Files in `*.generated.swift` or build artifacts may not exist until a build runs. Note this if documenting generated code. |
| **Dependency types** | Types from SPM/CocoaPods exist in `Pods/` or `.build/` — they're real but may not be in the project source. Note "from dependency: [library]" when referencing them. |
| **Protocol extensions** | A method may be defined in a protocol extension, not the conforming type directly. Check both. |
| **Computed properties** | Not all "getters" are functions. Check for `var <name>: Type { get }` patterns too. |
| **Objective-C bridging** | Some types may be defined in `.h`/`.m` files. If the project has mixed ObjC/Swift, search those too: `--include="*.h" --include="*.m"` |

---

## When to Flag vs. Remove

| Situation | Action |
|-----------|--------|
| Path exists but content changed significantly | Update description, no flag needed |
| Path doesn't exist, similar file found | Fix path, no flag |
| Path doesn't exist, nothing similar | Remove from docs |
| Type exists but behavior unclear | Keep type, flag behavior as `⚠️ INFERRED` |
| Type doesn't exist anywhere | Remove from docs |
| Behavior described is plausible but unconfirmed | Flag as `⚠️ INFERRED` |
| Behavior described contradicts code | Fix description to match code |
