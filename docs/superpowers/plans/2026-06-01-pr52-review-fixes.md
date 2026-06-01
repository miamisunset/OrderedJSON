# PR #52 Self-Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address 5 issues from the PR #52 self-review: remove unrelated docs, type-safe keywordCache, rawValue comparison fix, compositionKeywords constant, stronger validationKeywords test.

**Architecture:** 5 independent fixes in Sources/OrderedJSON/Schema/ and Tests/OrderedJSONTests/Schema/. Each is a small self-contained change. No new features.

**Tech Stack:** Swift 6.3, OrderedJSON library, Swift Testing

---

### Task 1: Remove unrelated dump-indent docs from the branch

**Files:**
- Delete: `docs/superpowers/plans/2026-05-31-dump-indent-redesign.md`
- Delete: `docs/superpowers/specs/2026-05-31-dump-indent-design.md`

These two files (combined ~1300 lines) describe a separate feature (dump indent API redesign) and add noise to the PR diff.

- [ ] **Step 1: Delete the plan doc**

Run: `git rm docs/superpowers/plans/2026-05-31-dump-indent-redesign.md`

- [ ] **Step 2: Delete the spec doc**

Run: `git rm docs/superpowers/specs/2026-05-31-dump-indent-design.md`

- [ ] **Step 3: Verify deletion**

Run: `git status` — confirm both files are staged for deletion.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: remove unrelated dump-indent docs from PR #52

These files describe a separate feature (dump indent API redesign)
and add ~1300 lines of noise to the typed JSONSchemaKeyword migration.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: Add static `compositionKeywords` to JSONSchemaKeyword enum

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Shared.swift` — add static constant

- [ ] **Step 1: Add compositionKeywords constant**

In `JSONSchema+Shared.swift`, after the enum cases but before the closing brace, add:

```swift

  // MARK: - Keyword groups

  /// Composition keywords whose values are arrays of subschemas.
  public static let compositionKeywords: [JSONSchemaKeyword] = [.allOf, .anyOf, .oneOf]
```

- [ ] **Step 2: Verify compilation**

Run: `swift build` — confirm it compiles without errors.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat: add JSONSchemaKeyword.compositionKeywords static constant

Extracts the repeated [.allOf, .anyOf, .oneOf] array literal into a
shared constant on the enum for DRY and consistency.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: Replace inline composition keyword arrays with the constant

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Compilation.swift` — 2 occurrences
- Modify: `Sources/OrderedJSON/Schema/JSONSchemaPatterns.swift` — 1 occurrence

Replace `[JSONSchemaKeyword.allOf, .anyOf, .oneOf]` with `JSONSchemaKeyword.compositionKeywords` at all call sites.

- [ ] **Step 1: Replace in JSONSchema+Compilation.swift line 161**

Change:
```swift
    for comp in [JSONSchemaKeyword.allOf, .anyOf, .oneOf] {
```
To:
```swift
    for comp in JSONSchemaKeyword.compositionKeywords {
```

- [ ] **Step 2: Replace in JSONSchema+Compilation.swift line 377**

Change:
```swift
    for keyword in [JSONSchemaKeyword.allOf, .anyOf, .oneOf] {
```
To:
```swift
    for keyword in JSONSchemaKeyword.compositionKeywords {
```

- [ ] **Step 3: Replace in JSONSchemaPatterns.swift line 45**

Change:
```swift
    for keyword in [JSONSchemaKeyword.allOf, .anyOf, .oneOf] {
```
To:
```swift
    for keyword in JSONSchemaKeyword.compositionKeywords {
```

- [ ] **Step 4: Verify compilation**

Run: `swift build`

- [ ] **Step 5: Commit**

```bash
git commit -m "refactor: use JSONSchemaKeyword.compositionKeywords across codebase

Replaces inline [.allOf, .anyOf, .oneOf] array literals in
Compilation.swift and Patterns.swift with the shared constant.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: Fix hasOtherKeys rawValue comparison in Validation.swift

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Validation.swift:323`

Replace the `.rawValue` comparison with a direct string comparison.

- [ ] **Step 1: Replace rawValue comparison**

In `JSONSchema+Validation.swift` around line 323, change:
```swift
          hasOtherKeys = dict.keys.contains(where: { $0 != JSONSchemaKeyword.dollarRef.rawValue })
```
To:
```swift
          hasOtherKeys = dict.keys.contains { $0 != "$ref" }
```

- [ ] **Step 2: Verify compilation**

Run: `swift build`

- [ ] **Step 3: Commit**

```bash
git commit -m "fix: replace rawValue comparison in hasOtherKeys with direct string

Uses the literal \"$ref\" instead of JSONSchemaKeyword.dollarRef.rawValue
for consistency with the typed enum migration pattern.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 5: Migrate keywordCache to type-safe enum keys

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Compilation.swift`
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Validation.swift`

Change `keywordCache` inner dictionary from `[String: JSON]` to `[JSONSchemaKeyword: JSON]`, update the builder and accessor.

- [ ] **Step 1: Change keywordCache type declaration in Compilation.swift**

In `JSONSchema+Compilation.swift` line 48, change:
```swift
  let keywordCache: [String: [String: JSON]]
```
To:
```swift
  let keywordCache: [String: [JSONSchemaKeyword: JSON]]
```

- [ ] **Step 2: Change buildKeywordCache return type**

In `JSONSchema+Compilation.swift` line 80, change:
```swift
  private static func buildKeywordCache(from schema: JSON) -> [String: [String: JSON]] {
    var cache: [String: [String: JSON]] = [:]
```
To:
```swift
  private static func buildKeywordCache(from schema: JSON) -> [String: [JSONSchemaKeyword: JSON]] {
    var cache: [String: [JSONSchemaKeyword: JSON]] = [:]
```

- [ ] **Step 3: Change buildKeywordCacheRecursive signature**

In `JSONSchema+Compilation.swift` lines 90-92, change:
```swift
  private static func buildKeywordCacheRecursive(
    _ value: JSON, pointer: String, cache: inout [String: [String: JSON]],
    depth: Int = 0
  ) {
```
To:
```swift
  private static func buildKeywordCacheRecursive(
    _ value: JSON, pointer: String, cache: inout [String: [JSONSchemaKeyword: JSON]],
    depth: Int = 0
  ) {
```

- [ ] **Step 4: Update inner keyword collection loop**

In `JSONSchema+Compilation.swift` lines 97-103, change:
```swift
    var keywords: [String: JSON] = [:]
    if case .object(let dict) = value.storage {
      for (k, v) in dict {
        keywords[k] = v
      }
    }
```
To:
```swift
    var keywords: [JSONSchemaKeyword: JSON] = [:]
    if case .object(let dict) = value.storage {
      for (k, v) in dict {
        if let kw = JSONSchemaKeyword(rawValue: k) {
          keywords[kw] = v
        }
      }
    }
```

This only caches values whose keys match known `JSONSchemaKeyword` cases. Non-keyword properties are not cached (they aren't needed by `keyword()` anyway).

- [ ] **Step 5: Update keyword() accessor in Validation.swift**

In `JSONSchema+Validation.swift` line 141, change:
```swift
    if let cache = compiled?.keywordCache[pointer], let v = cache[key.rawValue] {
```
To:
```swift
    if let cache = compiled?.keywordCache[pointer], let v = cache[key] {
```

- [ ] **Step 6: Verify compilation**

Run: `swift build` — confirm it compiles without errors.

- [ ] **Step 7: Run tests**

Run: `swift test` — confirm all tests pass.

- [ ] **Step 8: Commit**

```bash
git commit -m "refactor: migrate keywordCache to type-safe JSONSchemaKeyword keys

Changes the inner dictionary type from [String: JSON] to
[JSONSchemaKeyword: JSON] and updates the builder and accessor.
Eliminates the rawValue bridge in the keyword() function.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6: Strengthen validationKeywords test

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Validation.swift:122` — change access from `private` to `package`
- Modify: `Tests/OrderedJSONTests/Schema/JSONSchemaCreationTests.swift:106-122` — update test

- [ ] **Step 1: Change validationKeywords access level**

In `JSONSchema+Validation.swift` line 122, change:
```swift
  private static let validationKeywords: Set<JSONSchemaKeyword> = [
```
To:
```swift
  package static let validationKeywords: Set<JSONSchemaKeyword> = [
```

- [ ] **Step 2: Update test assertion**

In `JSONSchemaCreationTests.swift` around lines 106-122, replace the existing test function:

```swift
  @Test("JSONSchemaKeyword all validation cases are covered")
  func keywordAllValidationCases() {
    let allValidationKeywords: Set<JSONSchemaKeyword> = [
      .type, .properties, .required, .minimum, .maximum,
      .multipleOf, .pattern, .enum, .const, .minLength, .maxLength,
      .allOf, .anyOf, .oneOf, .not, .if, .minItems, .maxItems,
      .uniqueItems, .contains, .minProperties, .maxProperties,
      .propertyNames, .patternProperties, .additionalProperties,
      .items, .exclusiveMinimum, .exclusiveMaximum,
      .format, .dependencies, .additionalItems,
      .dependentSchemas, .dependentRequired, .prefixItems,
      .unevaluatedItems, .unevaluatedProperties,
      .contentMediaType, .contentEncoding, .contentSchema,
      .minContains, .maxContains,
    ]
    #expect(allValidationKeywords.count == 41)
  }
```

The hardcoded set stays (it documents the expected keywords), but the assertion changes to compare against production:

```swift
  @Test("JSONSchemaKeyword all validation cases are covered")
  func keywordAllValidationCases() {
    let allValidationKeywords: Set<JSONSchemaKeyword> = [
      .type, .properties, .required, .minimum, .maximum,
      .multipleOf, .pattern, .enum, .const, .minLength, .maxLength,
      .allOf, .anyOf, .oneOf, .not, .if, .minItems, .maxItems,
      .uniqueItems, .contains, .minProperties, .maxProperties,
      .propertyNames, .patternProperties, .additionalProperties,
      .items, .exclusiveMinimum, .exclusiveMaximum,
      .format, .dependencies, .additionalItems,
      .dependentSchemas, .dependentRequired, .prefixItems,
      .unevaluatedItems, .unevaluatedProperties,
      .contentMediaType, .contentEncoding, .contentSchema,
      .minContains, .maxContains,
    ]
    #expect(allValidationKeywords == JSONSchema.validationKeywords)
  }
```

- [ ] **Step 3: Verify compilation**

Run: `swift build`

- [ ] **Step 4: Run tests**

Run: `swift test` — confirm the test passes.

- [ ] **Step 5: Commit**

```bash
git commit -m "test: strengthen validationKeywords test to compare against production

Changes validationKeywords from private to package so the test can
reference it directly. The test now asserts equality with the
production set rather than just checking a hardcoded count.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 7: Final verification

- [ ] **Step 1: Run full test suite**

Run: `swift test` — verify all 1691+ tests pass.

- [ ] **Step 2: Check git status**

Run: `git status` — confirm only the intended files were modified.

- [ ] **Step 3: Check git diff**

Run: `git diff --stat` — verify no unexpected changes.
