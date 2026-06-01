# JSON Schema Error Keyword Typed Refactoring — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the migration of raw string keyword usage in JSON Schema errors and remaining source/test files to the typed `JSONSchemaKeyword` enum.

**Architecture:** Change `JSONSchemaError.keyword` from `String` to `JSONSchemaKeyword`, add `falseSchema`/`schemaError` cases, then mechanically replace all error creation sites and test assertions.

**Tech Stack:** Swift 6.3, Swift Testing

---

### Task 1: Add `falseSchema` and `schemaError` to `JSONSchemaKeyword` enum

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Shared.swift`

- [ ] **Step 1: Add the two new enum cases after the existing cases**

In `JSONSchema+Shared.swift`, add two new cases at the end of the enum (before the `compositionKeywords` static let):

```swift
  // MARK: - Special error categories

  /// Boolean `false` schema — rejects all values (not a standard keyword)
  case falseSchema = "false"

  /// Generic schema validation error (recursion limit, invalid structure, etc.)
  case schemaError = "schema"
```

- [ ] **Step 2: Verify the file compiles**

Run: `swift build`
Expected: Build succeeds without warnings

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Shared.swift
git commit -m "feat: add falseSchema and schemaError cases to JSONSchemaKeyword enum"
```

---

### Task 2: Change `JSONSchemaError.keyword` from `String` to `JSONSchemaKeyword`

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchemaError.swift`

- [ ] **Step 1: Change the `keyword` property type**

In `JSONSchemaError.swift`, change:
```swift
// Before
public let keyword: String

// After
public let keyword: JSONSchemaKeyword
```

- [ ] **Step 2: Change the `init` parameter type**

```swift
// Before
init(
  instancePath: String,
  schemaPath: String,
  keyword: String,
  ...

// After
init(
  instancePath: String,
  schemaPath: String,
  keyword: JSONSchemaKeyword,
  ...
```

- [ ] **Step 3: Update `description` to use `rawValue`**

```swift
// Before
public var description: String {
  "[\(keyword)] \(message) — instance: \(instancePath), schema: \(schemaPath)"
}

// After
public var description: String {
  "[\(keyword.rawValue)] \(message) — instance: \(instancePath), schema: \(schemaPath)"
}
```

- [ ] **Step 4: Build to verify**

Run: `swift build`
Expected: Compilation errors (expected — error creation sites still pass `String`)

- [ ] **Step 5: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchemaError.swift
git commit -m "refactor: change JSONSchemaError.keyword from String to JSONSchemaKeyword"
```

---

### Task 3: Update `JSONSchema.swift` error site

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema.swift` (line ~118)

- [ ] **Step 1: Change `keyword: "schema"` to `keyword: .schemaError`**

```swift
// Before
throw JSONSchemaError(
  instancePath: "",
  schemaPath: "",
  keyword: "schema",
  message: "Schema must be a JSON object or boolean"
)

// After
throw JSONSchemaError(
  instancePath: "",
  schemaPath: "",
  keyword: .schemaError,
  message: "Schema must be a JSON object or boolean"
)
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds (no more errors from this file)

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema.swift
git commit -m "refactor: use typed keyword in JSONSchema error site"
```

---

### Task 4: Update `JSONSchema+Array.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Array.swift`

- [ ] **Step 1: Replace keyword strings with enum values (4 sites)**

Lines ~20, ~39, ~61, ~93:
```swift
// Line ~20 — minItems
keyword: "minItems"  →  keyword: .minItems

// Line ~39 — maxItems
keyword: "maxItems"  →  keyword: .maxItems

// Line ~61 — uniqueItems
keyword: "uniqueItems"  →  keyword: .uniqueItems

// Line ~93 — contains
keyword: "contains"  →  keyword: .contains
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Array.swift
git commit -m "refactor: use typed keywords in Array validation errors"
```

---

### Task 5: Update `JSONSchema+Composition.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Composition.swift`

- [ ] **Step 1: Replace keyword strings with enum values (6 sites)**

Lines ~25, ~63, ~96, ~120, ~152, ~168:
```swift
// Line ~25 — allOf
keyword: "allOf"  →  keyword: .allOf

// Line ~63 — anyOf
keyword: "anyOf"  →  keyword: .anyOf

// Line ~96 — oneOf
keyword: "oneOf"  →  keyword: .oneOf

// Line ~120 — not
keyword: "not"  →  keyword: .not

// Line ~152 — then
keyword: "then"  →  keyword: .then

// Line ~168 — else
keyword: "else"  →  keyword: .else
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Composition.swift
git commit -m "refactor: use typed keywords in Composition validation errors"
```

---

### Task 6: Update `JSONSchema+Compilation.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Compilation.swift`

- [ ] **Step 1: Replace keyword strings with enum values (3 sites)**

Lines ~290, ~331, ~344:
```swift
// Line ~290 — $id
keyword: "$id"  →  keyword: .dollarId

// Line ~331 — $anchor
keyword: "$anchor"  →  keyword: .dollarAnchor

// Line ~344 — $dynamicAnchor
keyword: "$dynamicAnchor"  →  keyword: .dollarDynamicAnchor
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Compilation.swift
git commit -m "refactor: use typed keywords in Compilation errors"
```

---

### Task 7: Update `JSONSchema+Draft202012.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Draft202012.swift`

- [ ] **Step 1: Replace keyword strings with enum values (2 sites)**

Lines ~35, ~64:
```swift
// Line ~35 — dependentSchemas
keyword: "dependentSchemas"  →  keyword: .dependentSchemas

// Line ~64 — dependentRequired
keyword: "dependentRequired"  →  keyword: .dependentRequired
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Draft202012.swift
git commit -m "refactor: use typed keywords in Draft202012 errors"
```

---

### Task 8: Update `JSONSchema+Draft7.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Draft7.swift`

- [ ] **Step 1: Replace keyword strings with enum values (6 sites)**

Lines ~28, ~39, ~65, ~76, ~106, ~139, ~151, ~162:
```swift
// Lines ~28, ~39 — exclusiveMinimum
keyword: "exclusiveMinimum"  →  keyword: .exclusiveMinimum

// Lines ~65, ~76 — exclusiveMaximum
keyword: "exclusiveMaximum"  →  keyword: .exclusiveMaximum

// Line ~106 — format
keyword: "format"  →  keyword: .format

// Lines ~139, ~151, ~162 — dependencies
keyword: "dependencies"  →  keyword: .dependencies
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Draft7.swift
git commit -m "refactor: use typed keywords in Draft7 errors"
```

---

### Task 9: Update `JSONSchema+Numeric.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Numeric.swift`

- [ ] **Step 1: Replace keyword strings with enum values (8 sites)**

Lines ~20, ~30, ~50, ~60, ~81, ~92, ~114, ~125, ~149, ~164, ~175:
```swift
// Lines ~20, ~30 — minimum
keyword: "minimum"  →  keyword: .minimum

// Lines ~50, ~60 — maximum
keyword: "maximum"  →  keyword: .maximum

// Lines ~81, ~92 — exclusiveMinimum
keyword: "exclusiveMinimum"  →  keyword: .exclusiveMinimum

// Lines ~114, ~125 — exclusiveMaximum
keyword: "exclusiveMaximum"  →  keyword: .exclusiveMaximum

// Lines ~149, ~164, ~175 — multipleOf
keyword: "multipleOf"  →  keyword: .multipleOf
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Numeric.swift
git commit -m "refactor: use typed keywords in Numeric validation errors"
```

---

### Task 10: Update `JSONSchema+Object.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Object.swift`

- [ ] **Step 1: Replace keyword strings with enum values (3 sites)**

Lines ~19, ~37, ~64:
```swift
// Line ~19 — minProperties
keyword: "minProperties"  →  keyword: .minProperties

// Line ~37 — maxProperties
keyword: "maxProperties"  →  keyword: .maxProperties

// Line ~64 — propertyNames
keyword: "propertyNames"  →  keyword: .propertyNames
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Object.swift
git commit -m "refactor: use typed keywords in Object validation errors"
```

---

### Task 11: Update `JSONSchema+Patterns.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Patterns.swift`

- [ ] **Step 1: Replace keyword strings with enum values (2 sites)**

Lines ~20, ~75:
```swift
// Line ~20 — pattern
keyword: "pattern"  →  keyword: .pattern

// Line ~75 — patternProperties
keyword: "patternProperties"  →  keyword: .patternProperties
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Patterns.swift
git commit -m "refactor: use typed keywords in Patterns errors"
```

---

### Task 12: Update `JSONSchema+Properties.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Properties.swift`

- [ ] **Step 1: Replace keyword strings with enum values (2 sites)**

Lines ~43, ~52:
```swift
// Lines ~43, ~52 — required
keyword: "required"  →  keyword: .required
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Properties.swift
git commit -m "refactor: use typed keywords in Properties validation errors"
```

---

### Task 13: Update `JSONSchema+String.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+String.swift`

- [ ] **Step 1: Replace keyword strings with enum values (5 sites)**

Lines ~33, ~59, ~78, ~101, ~123:
```swift
// Line ~33 — pattern
keyword: "pattern"  →  keyword: .pattern

// Line ~59 — enum
keyword: "enum"  →  keyword: .enum

// Line ~78 — const
keyword: "const"  →  keyword: .const

// Line ~101 — minLength
keyword: "minLength"  →  keyword: .minLength

// Line ~123 — maxLength
keyword: "maxLength"  →  keyword: .maxLength
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+String.swift
git commit -m "refactor: use typed keywords in String validation errors"
```

---

### Task 14: Update `JSONSchema+Type.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Type.swift`

- [ ] **Step 1: Replace keyword strings with enum values (2 sites)**

Lines ~23, ~36:
```swift
// Lines ~23, ~36 — type
keyword: "type"  →  keyword: .type
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Type.swift
git commit -m "refactor: use typed keywords in Type validation errors"
```

---

### Task 15: Update `JSONSchema+Unevaluated.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Unevaluated.swift`

- [ ] **Step 1: Replace keyword strings with enum values (2 sites)**

Lines ~413, ~445:
```swift
// Line ~413 — minContains
keyword: "minContains"  →  keyword: .minContains

// Line ~445 — maxContains
keyword: "maxContains"  →  keyword: .maxContains
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Unevaluated.swift
git commit -m "refactor: use typed keywords in Unevaluated errors"
```

---

### Task 16: Update `JSONSchema+Validation.swift` error sites

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Validation.swift`

- [ ] **Step 1: Replace keyword strings with enum values (4 sites)**

Lines ~160, ~186, ~276, ~311, ~332:
```swift
// Line ~160 — schema (recursion depth)
keyword: "schema"  →  keyword: .schemaError

// Line ~186 — false (boolean false schema)
keyword: "false"  →  keyword: .falseSchema

// Line ~276 — $dynamicRef
keyword: "$dynamicRef"  →  keyword: .dollarDynamicRef

// Lines ~311, ~332 — $ref
keyword: "$ref"  →  keyword: .dollarRef
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Schema/JSONSchema+Validation.swift
git commit -m "refactor: use typed keywords in Validation errors"
```

---

### Task 17: Run full build to verify all source files compile

- [ ] **Step 1: Full build**

Run: `swift build`
Expected: Build succeeds with no errors

- [ ] **Step 2: Commit any remaining uncommitted source changes**

```bash
git add Sources/OrderedJSON/
git commit -m "refactor: complete typed keyword migration in all source files"
```

---

### Task 18: Update test assertions — direct keyword comparisons

**Files:**
- Modify: All test files in `Tests/OrderedJSONTests/Schema/` that compare `.keyword` against string literals

This task covers ~60 assertions that use `#expect(result.errors.first?.keyword == "stringLiteral")` pattern.

- [ ] **Step 1: Update all direct comparison assertions**

Replace `== "keywordString"` with `== .keywordEnumValue` in all test files.

Key mappings for special cases:
- `"false"` → `.falseSchema`
- `"schema"` → `.schemaError`
- `"$ref"` → `.dollarRef`
- `"$dynamicRef"` → `.dollarDynamicRef`
- `"$id"` → `.dollarId`
- `"$anchor"` → `.dollarAnchor`
- `"$dynamicAnchor"` → `.dollarDynamicAnchor`
- All standard keyword strings map to their `.caseName` directly

Files to update (exhaustive list):
- `JSONSchemaAdditionalItemsTests.swift` — `"additionalItems"`, `"type"`
- `JSONSchemaAdditionalPropertiesTests.swift` — `"false"`
- `JSONSchemaAllOfTests.swift` — `"allOf"`
- `JSONSchemaAnyOfTests.swift` — `"anyOf"`
- `JSONSchemaBooleanEdgeCasesTests.swift` — `"allOf"`, `"anyOf"`, `"oneOf"`
- `JSONSchemaBooleanTests.swift` — `"false"`
- `JSONSchemaCompiledNestedAnnotationTests.swift` — `"$ref"`
- `JSONSchemaConstTests.swift` — `"const"`
- `JSONSchemaContainsTests.swift` — `"contains"`
- `JSONSchemaDependentRequiredTests.swift` — `"dependentRequired"`
- `JSONSchemaDependentSchemasTests.swift` — `"dependentSchemas"`
- `JSONSchemaDynamicRefTests.swift` — `"schema"`, `"$dynamicRef"`, `"allOf"`
- `JSONSchemaEnumTests.swift` — `"enum"`
- `JSONSchemaExclusiveBoundsTests.swift` — `"exclusiveMinimum"`, `"exclusiveMaximum"`
- `JSONSchemaIfThenElseTests.swift` — `"then"`, `"else"`
- `JSONSchemaIntegrationTests.swift` — `"required"`, `"type"`, `"maximum"`
- `JSONSchemaItemsTests.swift` — `"items"`, `"type"`
- `JSONSchemaMinMaxContainsEdgeCasesTests.swift` — `"minContains"`, `"maxContains"`
- `JSONSchemaMinMaxItemsTests.swift` — `"minItems"`, `"maxItems"`
- `JSONSchemaMinMaxPropertiesTests.swift` — `"minProperties"`, `"maxProperties"`
- `JSONSchemaMultipleOfTests.swift` — `"multipleOf"`
- `JSONSchemaNotTests.swift` — `"not"`
- `JSONSchemaNumericBoundsTests.swift` — `"minimum"`, `"maximum"`
- `JSONSchemaOneOfTests.swift` — `"oneOf"`
- `JSONSchemaOutputModeTests.swift` — `"allOf"`
- `JSONSchemaPatternPropertiesTests.swift` — `"patternProperties"`, `"type"`
- `JSONSchemaPatternTests.swift` — `"pattern"`
- `JSONSchemaPrefixItemsTests.swift` — `"prefixItems"`, `"type"`
- `JSONSchemaPropertiesTests.swift` — `"type"`
- `JSONSchemaPropertyNamesTests.swift` — `"propertyNames"`
- `JSONSchemaRefEdgeCasesTests.swift` — `"$ref"`
- `JSONSchemaRefTests.swift` — `"$ref"`
- `JSONSchemaRequiredTests.swift` — `"required"`
- `JSONSchemaReviewEdgeCasesTests.swift` — `"dependentSchemas"`
- `JSONSchemaTypeValidationTests.swift` — `"type"`
- `JSONSchemaUnevaluatedItemsTests.swift` — `"unevaluatedItems"`, `"type"`
- `JSONSchemaUnevaluatedPropertiesTests.swift` — `"false"`
- `JSONSchemaUniqueItemsTests.swift` — `"uniqueItems"`
- `JSONMemoryPerformanceSchemaTests.swift` — `"$ref"`, `"schema"`
- `READMESchemaTests.swift` — `error.keyword != ""` check

For `READMESchemaTests.swift:56` — change:
```swift
// Before
#expect(error.keyword != "")

// After
#expect(error.keyword != JSONSchemaKeyword?.none)  // won't compile — keyword is non-optional
```
→ Use rawValue check instead:
```swift
#expect(!error.keyword.rawValue.isEmpty)
```

- [ ] **Step 2: Build tests**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Tests/OrderedJSONTests/
git commit -m "test: update keyword assertions to use typed enum comparisons"
```

---

### Task 19: Update test assertions — keypath-based keyword comparisons

**Files:**
- Modify: 5 test files using `\.keyword` keypath in `map()`:
  - `JSONSchemaAdditionalItemsTests.swift` (lines 32-33)
  - `JSONSchemaPrefixItemsTests.swift` (lines 35-36)
  - `JSONSchemaUnevaluatedItemsTests.swift` (lines 32-33)
  - `JSONSchemaPatternPropertiesTests.swift` (lines 34-35)
  - `JSONSchemaItemsTests.swift` (lines 22-23)

- [ ] **Step 1: Replace keypath syntax with closure and enum comparisons**

For each file, change pattern from:
```swift
result.errors.map(\.keyword).contains("keywordName")
  || result.errors.map(\.keyword).contains("type")
```

To:
```swift
result.errors.map(\.keyword).contains(.keywordName)
  || result.errors.map(\.keyword).contains(.type)
```

Note: `\.keyword` keypath still works — it now produces `JSONSchemaKeyword` values. The `contains()` method needs a `JSONSchemaKeyword` argument instead of `String`.

For `JSONSchemaAdditionalItemsTests.swift:32-33`:
```swift
// Before
result.errors.map(\.keyword).contains("additionalItems")
  || result.errors.map(\.keyword).contains("type")

// After
result.errors.map(\.keyword).contains(.additionalItems)
  || result.errors.map(\.keyword).contains(.type)
```

For `JSONSchemaPrefixItemsTests.swift:35-36`:
```swift
// Before
result.errors.map(\.keyword).contains("prefixItems")
  || result.errors.map(\.keyword).contains("type")

// After
result.errors.map(\.keyword).contains(.prefixItems)
  || result.errors.map(\.keyword).contains(.type)
```

For `JSONSchemaUnevaluatedItemsTests.swift:32-33`:
```swift
// Before
result.errors.map(\.keyword).contains("unevaluatedItems")
  || result.errors.map(\.keyword).contains("type")

// After
result.errors.map(\.keyword).contains(.unevaluatedItems)
  || result.errors.map(\.keyword).contains(.type)
```

For `JSONSchemaPatternPropertiesTests.swift:34-35`:
```swift
// Before
result.errors.map(\.keyword).contains("patternProperties")
  || result.errors.map(\.keyword).contains("type")

// After
result.errors.map(\.keyword).contains(.patternProperties)
  || result.errors.map(\.keyword).contains(.type)
```

For `JSONSchemaItemsTests.swift:22-23`:
```swift
// Before
result.errors.map(\.keyword).contains("items")
  || result.errors.map(\.keyword).contains("type")

// After
result.errors.map(\.keyword).contains(.items)
  || result.errors.map(\.keyword).contains(.type)
```

- [ ] **Step 2: Build tests**

Run: `swift build`
Expected: Succeeds

- [ ] **Step 3: Commit**

```bash
git add Tests/OrderedJSONTests/
git commit -m "test: update keypath-based keyword assertions to use enum values"
```

---

### Task 20: Run full test suite

- [ ] **Step 1: Run all schema tests**

Run: `swift test 2>&1 | tail -50`
Expected: All tests pass

- [ ] **Step 2: If any tests fail, diagnose and fix**

Check for any test that still compares `String` against `JSONSchemaKeyword` or uses incorrect enum value.

- [ ] **Step 3: Final commit if fixes needed**

```bash
git add Tests/OrderedJSONTests/ Sources/OrderedJSON/
git commit -m "fix: correct remaining keyword comparisons after test run"
```

---

### Task 21: Run pre-push validation

- [ ] **Step 1: Lint**

Run: `swift format lint --recursive --parallel -p .`
Expected: No lint errors (or minimal)

- [ ] **Step 2: Format if needed**

Run: `swift format format --recursive --parallel --in-place -p .`
Expected: Formatting applied

- [ ] **Step 3: Final build**

Run: `swift build && swift test`
Expected: Build + all tests pass

- [ ] **Step 4: Commit any formatting changes**

```bash
git add .
git commit -m "chore: apply swiftformat after keyword refactoring"
```
