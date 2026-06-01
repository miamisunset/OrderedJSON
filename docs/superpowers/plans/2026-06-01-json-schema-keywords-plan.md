# JSON Schema Keyword Typed Enum Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all raw string keyword accesses (`subschema["type"]`) with a typed `JSONSchemaKeyword` enum (`subschema[key: .type]`) across the schema codebase.

**Architecture:** A `JSONSchemaKeyword` enum with `String` raw values covers all ~50 JSON Schema keywords. A `subscript(key:)` overload on `JSON` accepts the enum. All keyword-set types (`validationKeywords`, `vocabularyKeywords`, `subschemaKeywords`, `enabledKeywords`) migrate from `Set<String>` to `Set<JSONSchemaKeyword>`. The `keyword()` helper and `keywordEnabled()` closure also migrate.

**Tech Stack:** Swift 6.3, no external dependencies beyond `swift-collections`.

**Skills used for guidance:** `swift-api-design-guidelines-skill` (API naming), `swift-testing-pro` (testing patterns).

---

## File Structure

**Files modified** (15 source files, 1 test file):

| File | Responsibility |
|------|---------------|
| `JSONSchema+Shared.swift` | Define `JSONSchemaKeyword` enum, add `subscript(key:)` on `JSON` |
| `JSONSchema+Compilation.swift` | Migrate `subschemaKeywords`, `keywordCache`, all `schema[...]`/`value[...]` accesses |
| `JSONSchema+Validation.swift` | Migrate `validationKeywords`, `keyword()`, `keywordEnabled()`, switch cases, all `subschema[...]` accesses |
| `JSONSchema+Object.swift` | Migrate all `subschema[...]` accesses |
| `JSONSchema+Array.swift` | Migrate all `subschema[...]` accesses |
| `JSONSchema+Numeric.swift` | Migrate all `subschema[...]` accesses |
| `JSONSchema+Properties.swift` | Migrate all `subschema[...]` accesses |
| `JSONSchema+String.swift` | Migrate all `subschema[...]` accesses |
| `JSONSchema+Composition.swift` | Migrate all `subschema[...]` accesses |
| `JSONSchema+Unevaluated.swift` | Migrate all `subschema[...]` accesses |
| `JSONSchema+Draft7.swift` | Migrate all `subschema[...]` accesses |
| `JSONSchema+Draft202012.swift` | Migrate all `subschema[...]` accesses |
| `JSONSchema+Draft.swift` | Migrate `vocabularyKeywords`, `enabledKeywords(from:)` |
| `JSONSchema+Ref.swift` | Migrate `target["..."]` accesses |
| `JSONSchema+Patterns.swift` | Migrate all `schema[...]` accesses |
| `JSONSchemaContext.swift` | Migrate `enabledKeywords` type |
| `JSONSchemaCreationTests.swift` | Add round-trip test for enum |

---

### Task 1: Define `JSONSchemaKeyword` enum and JSON subscript

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Shared.swift` — add enum definition + subscript

**Steps:**

- [ ] **Step 1: Add enum definition at top of file (before `extension JSONSchema`)**

```swift
/// A typed representation of JSON Schema keyword names.
///
/// Using this enum instead of raw string keys prevents typos and enables
/// autocomplete. Use with the `subscript(key:)` overload on `JSON`:
///
/// ```swift
/// subschema[key: .type]
/// subschema[key: .properties]
/// subschema[key: .dollarRef]
/// ```
public enum JSONSchemaKeyword: String, Hashable, Sendable, CaseIterable {
  // MARK: - Meta-keywords ($-prefixed → camelCase with "dollar" prefix)

  /// `$id` — schema resource identifier
  case dollarId = "$id"
  /// `$ref` — JSON Schema reference
  case dollarRef = "$ref"
  /// `$defs` — shared schema definitions
  case dollarDefs = "$defs"
  /// `$anchor` — plain-name anchor
  case dollarAnchor = "$anchor"
  /// `$dynamicAnchor` — dynamic-scope anchor
  case dollarDynamicAnchor = "$dynamicAnchor"
  /// `$dynamicRef` — dynamic-scope reference
  case dollarDynamicRef = "$dynamicRef"
  /// `$schema` — metaschema URI
  case dollarSchema = "$schema"
  /// `$vocabulary` — vocabulary declaration
  case dollarVocabulary = "$vocabulary"
  /// `$comment` — annotation comment
  case dollarComment = "$comment"

  // MARK: - Validation keywords

  /// `type` — value type constraint
  case type
  /// `const` — exact value constraint
  case `const`
  /// `enum` — allowed values list
  case `enum`
  /// `multipleOf` — divisor constraint
  case multipleOf
  /// `maximum` — numeric upper bound
  case maximum
  /// `exclusiveMaximum` — strict numeric upper bound
  case exclusiveMaximum
  /// `minimum` — numeric lower bound
  case minimum
  /// `exclusiveMinimum` — strict numeric lower bound
  case exclusiveMinimum
  /// `maxLength` — maximum string length
  case maxLength
  /// `minLength` — minimum string length
  case minLength
  /// `pattern` — regex string constraint
  case pattern
  /// `format` — string format constraint (Draft 7 assertion)
  case format
  /// `maxItems` — maximum array length
  case maxItems
  /// `minItems` — minimum array length
  case minItems
  /// `uniqueItems` — array uniqueness constraint
  case uniqueItems
  /// `maxContains` — maximum matching items in contains
  case maxContains
  /// `minContains` — minimum matching items in contains
  case minContains
  /// `maxProperties` — maximum object property count
  case maxProperties
  /// `minProperties` — minimum object property count
  case minProperties
  /// `required` — required property names
  case required
  /// `dependentRequired` — conditional required properties (Draft 2020-12)
  case dependentRequired

  // MARK: - Applicator keywords

  /// `properties` — property-schema map
  case properties
  /// `patternProperties` — regex-keyed property schemas
  case patternProperties
  /// `additionalProperties` — schema for extra properties
  case additionalProperties
  /// `propertyNames` — schema for property name strings
  case propertyNames
  /// `dependentSchemas` — conditional object schemas (Draft 2020-12)
  case dependentSchemas
  /// `items` — array item schema (or tuple in Draft 7)
  case items
  /// `prefixItems` — tuple schemas for first items (Draft 2020-12)
  case prefixItems
  /// `additionalItems` — schema for extra tuple items (Draft 7)
  case additionalItems
  /// `unevaluatedItems` — schema for items not evaluated by other keywords
  case unevaluatedItems
  /// `unevaluatedProperties` — schema for properties not evaluated by other keywords
  case unevaluatedProperties
  /// `contains` — array must contain matching item
  case contains
  /// `allOf` — all subschemas must match
  case allOf
  /// `anyOf` — at least one subschema must match
  case anyOf
  /// `oneOf` — exactly one subschema must match
  case oneOf
  /// `not` — subschema must not match
  case not
  /// `if` — conditional schema branch
  case `if`
  /// `then` — schema when `if` matches
  case `then`
  /// `else` — schema when `if` fails
  case `else`

  // MARK: - Content keywords (Draft 2020-12)

  /// `contentMediaType` — media type of the content
  case contentMediaType
  /// `contentEncoding` — encoding of the content
  case contentEncoding
  /// `contentSchema` — schema for decoded content
  case contentSchema

  // MARK: - Annotation keywords

  /// `title` — schema title
  case title
  /// `description` — schema description
  case description
  /// `default` — default value
  case `default`
  /// `examples` — example values
  case examples
  /// `readOnly` — read-only flag
  case readOnly
  /// `writeOnly` — write-only flag
  case writeOnly
  /// `deprecated` — deprecation flag
  case deprecated

  // MARK: - Draft 7 legacy keywords

  /// `dependencies` — Draft 7 property dependencies
  case dependencies
  /// `definitions` — Draft 7 shared definitions (superseded by $defs)
  case definitions
}
```

- [ ] **Step 2: Add JSON subscript overload after the enum definition**

```swift
extension JSON {
  /// Accesses a schema keyword value from a JSON object using the typed
  /// `JSONSchemaKeyword` enum instead of a raw string key.
  ///
  /// ```swift
  /// subschema[key: .type]     // instead of subschema["type"]
  /// subschema[key: .minimum]  // instead of subschema["minimum"]
  /// ```
  subscript(key schemaKeyword: JSONSchemaKeyword) -> JSON? {
    self[schemaKeyword.rawValue]
  }
}
```

- [ ] **Step 3: Run build to verify compilation**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build 2>&1
```
Expected: Build succeeds (the enum and subscript are unused yet, so no errors).

- [ ] **Step 4: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Sources/OrderedJSON/Schema/JSONSchema+Shared.swift && git commit -m "feat: add JSONSchemaKeyword enum and typed subscript on JSON"
```

---

### Task 2: Migrate `JSONSchema+Compilation.swift` — keyword sets and all `schema[...]`/`value[...]` accesses

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Compilation.swift`

This file uses `value["..."]` and `schema["..."]` extensively in `buildKeywordCacheRecursive`, `collectRegexPatterns`, and `collectResourcesRecursive`. It also defines `subschemaKeywords: [String]`.

- [ ] **Step 1: Change `subschemaKeywords` type**

Current (line 62):
```swift
private static let subschemaKeywords: [String] = [
  "items", "allOf", "anyOf", "oneOf", "not", "if", "then", "else",
  "contains", "additionalProperties", "unevaluatedProperties",
  "additionalItems", "unevaluatedItems", "contentSchema",
]
```

New:
```swift
private static let subschemaKeywords: [JSONSchemaKeyword] = [
  .items, .allOf, .anyOf, .oneOf, .not, .if, .then, .else,
  .contains, .additionalProperties, .unevaluatedProperties,
  .additionalItems, .unevaluatedItems, .contentSchema,
]
```

- [ ] **Step 2: Update `collectRegexPatterns` — change all `value["..."]` to `value[key: .keyword]`**

The function uses `value["pattern"]`, `value["patternProperties"]`, `value["properties"]`, `value["$defs"]`, `value["definitions"]`, and iterates `Self.subschemaKeywords` with `value[keyword]`. Change each:

```swift
// Before:
if let patternStr = value["pattern"]?.stringValue
// After:
if let patternStr = value[key: .pattern]?.stringValue

// Before:
if let pp = value["patternProperties"], pp.isObject
// After:
if let pp = value[key: .patternProperties], pp.isObject

// Before:
if let properties = value["properties"], properties.isObject
// After:
if let properties = value[key: .properties], properties.isObject

// Before:
for keyword in Self.subschemaKeywords {
  if let subschema = value[keyword], subschema.isObject {
// After:
for keyword in Self.subschemaKeywords {
  if let subschema = value[key: keyword], subschema.isObject {

// Before:
if let defs = value["$defs"], defs.isObject
// After:
if let defs = value[key: .dollarDefs], defs.isObject

// Before:
if let defs = value["definitions"], defs.isObject
// After:
if let defs = value[key: .definitions], defs.isObject
```

- [ ] **Step 3: Update `buildKeywordCacheRecursive` — change all `value["..."]` to `value[key: .keyword]`**

Same pattern as above. All `value["properties"]`, `value["items"]`, `value["$defs"]`, `value["definitions"]`, `value["patternProperties"]`, `value["additionalProperties"]`, `value["unevaluatedProperties"]`, `value["allOf"]`, `value["anyOf"]`, `value["oneOf"]`, `value["not"]`, `value["if"]`, `value["then"]`, `value["else"]` become `value[key: .keyword]`.

The inner keyword collection loop also changes:
```swift
// Before:
for (k, v) in dict {
  keywords[k] = v
}
// After: (no change needed — this iterates raw keys from JSON, not our enum)
// The `keywords` dictionary is still `[String: JSON]` because it stores
// whatever keys the JSON object has (which are always strings).
```

- [ ] **Step 4: Update `collectResourcesRecursive` — change all `schema["..."]` to `schema[key: .keyword]`**

This is the largest set of changes. Every `schema["..."]` access becomes `schema[key: .keyword]`.

```swift
// Before:
let childID = schema["$id"]?.stringValue
// After:
let childID = schema[key: .dollarId]?.stringValue

// Before:
if let defsJSON = schema["$defs"], defsJSON.isObject
// After:
if let defsJSON = schema[key: .dollarDefs], defsJSON.isObject

// ... same for all ~25 keywords in this function
```

- [ ] **Step 5: Update the `keywordCache` dictionary type in the struct definition**

Current (line 48):
```swift
let keywordCache: [String: [String: JSON]]
```

The cache stores string→JSON mappings per pointer. The inner dictionary is built from schema keys (which are always strings). Leave this as `[String: JSON]` — the cache stores whatever keys the JSON schema object has. Only the `keyword()` function's parameter type changes.

- [ ] **Step 6: Run build to verify**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build 2>&1
```

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Sources/OrderedJSON/Schema/JSONSchema+Compilation.swift && git commit -m "refactor: migrate Compilation.swift to typed JSONSchemaKeyword enum"
```

---

### Task 3: Migrate `JSONSchema+Validation.swift` — validationKeywords, keyword(), keywordEnabled(), switch cases, and all subschema[...] accesses

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Validation.swift`

This file has the most changes:
1. `validationKeywords: Set<String>` → `Set<JSONSchemaKeyword>`
2. `keyword(_ key: String, ...)` → `keyword(_ key: JSONSchemaKeyword, ...)`
3. `keywordEnabled(_ kw: String)` → `keywordEnabled(_ kw: JSONSchemaKeyword)`
4. The switch statement in `validateValue` — keys are still strings (from JSON object iteration), but we convert to enum for dispatch
5. All `subschema["..."]` accesses

- [ ] **Step 1: Change `validationKeywords` type and values**

Current (lines 122-134):
```swift
private static let validationKeywords: Set<String> = [
  "type", "properties", "required", "minimum", "maximum",
  "multipleOf", "pattern", "enum", "const", "minLength", "maxLength",
  "allOf", "anyOf", "oneOf", "not", "if", "minItems", "maxItems",
  "uniqueItems", "contains", "minProperties", "maxProperties",
  "propertyNames", "patternProperties", "additionalProperties",
  "items", "exclusiveMinimum", "exclusiveMaximum",
  "format", "dependencies", "additionalItems",
  "dependentSchemas", "dependentRequired", "prefixItems",
  "unevaluatedItems", "unevaluatedProperties",
  "contentMediaType", "contentEncoding", "contentSchema",
  "minContains", "maxContains",
]
```

New:
```swift
private static let validationKeywords: Set<JSONSchemaKeyword> = [
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
```

- [ ] **Step 2: Update `keyword()` function parameter type**

Current (lines 138-145):
```swift
func keyword(
  _ key: String, from subschema: JSON, at pointer: String
) -> JSON? {
  if let cache = compiled?.keywordCache[pointer], let v = cache[key] {
    return v
  }
  return subschema[key]
}
```

New:
```swift
func keyword(
  _ key: JSONSchemaKeyword, from subschema: JSON, at pointer: String
) -> JSON? {
  if let cache = compiled?.keywordCache[pointer], let v = cache[key.rawValue] {
    return v
  }
  return subschema[key: key]
}
```

- [ ] **Step 3: Update `keywordEnabled()` closure parameter type**

Current (line 246):
```swift
func keywordEnabled(_ kw: String) -> Bool {
  guard let set = currentCtx.enabledKeywords else { return true }
  return set.contains(kw)
}
```

New:
```swift
func keywordEnabled(_ kw: JSONSchemaKeyword) -> Bool {
  guard let set = currentCtx.enabledKeywords else { return true }
  return set.contains(kw)
}
```

- [ ] **Step 4: Update the switch statement in `validateValue`**

The switch currently dispatches on `key` (a string from dict iteration). Since dict keys are still `String` (from JSON parsing), we need to convert to enum:

Current (lines 378-380):
```swift
for (key, _) in dict {
  guard validationKeywords.contains(key) else { continue }
  guard keywordEnabled(key) else { continue }
```

New — convert to enum for the set lookups:
```swift
for (key, _) in dict {
  // Convert the string key to our enum for typed comparisons.
  // Unknown keywords (not in JSONSchemaKeyword) fall through to default.
  guard let kw = JSONSchemaKeyword(rawValue: key) else { continue }
  guard validationKeywords.contains(kw) else { continue }
  guard keywordEnabled(kw) else { continue }

  switch kw {
  case .type:
    // ...
  case .properties:
    // ...
  // ... all cases using the enum instead of string literals
  default:
    break
  }
}
```

The switch cases change from `case "type":` to `case .type:`, etc.

- [ ] **Step 5: Update all other `subschema["..."]` accesses in this file**

These include:
- `subschema["$ref"]?.stringValue` → `subschema[key: .dollarRef]?.stringValue`
- `subschema["$id"]?.stringValue` → `subschema[key: .dollarId]?.stringValue`
- `subschema["$dynamicRef"]?.stringValue` → `subschema[key: .dollarDynamicRef]?.stringValue`
- `subschema["$dynamicAnchor"]?.stringValue` → `subschema[key: .dollarDynamicAnchor]?.stringValue`
- `subschema["$schema"]?.stringValue` → `subschema[key: .dollarSchema]?.stringValue`
- `subschema["$vocabulary"]?.objectValue` (in enabledKeywords) → `subschema[key: .dollarVocabulary]?.objectValue` (actually this is in Draft.swift, not Validation.swift)

Wait, the `$vocabulary` access is in Draft.swift. Let me check... `subschema["$schema"]?.stringValue` is in Validation.swift at line 199. And `subschema["$vocabulary"]` is in Draft.swift.

- [ ] **Step 6: Run build to verify**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build 2>&1
```

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Sources/OrderedJSON/Schema/JSONSchema+Validation.swift && git commit -m "refactor: migrate Validation.swift to typed JSONSchemaKeyword enum"
```

---

### Task 4: Migrate `JSONSchema+Object.swift` — all subschema[...] accesses

**Files:**
- Modify: `Sources/OrderedJSON/Schema/JSONSchema+Object.swift`

This file has ~20 `subschema["..."]` accesses for object-related keywords.

- [ ] **Step 1: Replace all `subschema["..."]` with `subschema[key: .keyword]`**

Changes:

| Line | Current | New |
|------|---------|-----|
| 14 | `subschema["minProperties"]?.intValue` | `subschema[key: .minProperties]?.intValue` |
| 32 | `subschema["maxProperties"]?.intValue` | `subschema[key: .maxProperties]?.intValue` |
| 50 | `subschema["propertyNames"]` | `subschema[key: .propertyNames]` |
| 78 | `subschema["patternProperties"]` | `subschema[key: .patternProperties]` |
| 115 | `subschema["additionalProperties"]` | `subschema[key: .additionalProperties]` |
| 150 | `subschema["properties"]` | `subschema[key: .properties]` |
| 158 | `subschema["patternProperties"]` | `subschema[key: .patternProperties]` |
| 178 | `subschema["additionalProperties"]` | `subschema[key: .additionalProperties]` |
| 200 | `subschema["$ref"]?.stringValue` | `subschema[key: .dollarRef]?.stringValue` |
| 216 | `subschema["$dynamicRef"]?.stringValue` | `subschema[key: .dollarDynamicRef]?.stringValue` |
| 233 | `subschema["dependentSchemas"]` | `subschema[key: .dependentSchemas]` |
| 248 | `subschema["allOf"]` | `subschema[key: .allOf]` |
| 272 | `subschema["anyOf"]` | `subschema[key: .anyOf]` |
| 304 | `subschema["oneOf"]` | `subschema[key: .oneOf]` |
| 336 | `subschema["if"]` | `subschema[key: .if]` |
| 361 | `subschema["then"]` | `subschema[key: .then]` |
| 381 | `subschema["else"]` | `subschema[key: .else]` |
| 405 | `subschema["unevaluatedProperties"]` | `subschema[key: .unevaluatedProperties]` |

- [ ] **Step 2: Run build**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build 2>&1
```

- [ ] **Step 3: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Sources/OrderedJSON/Schema/JSONSchema+Object.swift && git commit -m "refactor: migrate Object.swift to typed JSONSchemaKeyword enum"
```

---

### Task 5: Migrate remaining source files (Array, Numeric, Properties, String, Composition, Unevaluated, Draft7, Draft202012, Draft, Ref, Patterns, Context)

**Files:**
- Modify: All remaining Schema source files

These are straightforward find-and-replace tasks. Each file has a mix of `subschema["..."]`, `schema["..."]`, `value["..."]`, `target["..."]`, and `metaschema["..."]` accesses.

- [ ] **Step 1: Migrate `JSONSchema+Array.swift`**

Changes:
- `subschema["minItems"]?.intValue` → `subschema[key: .minItems]?.intValue`
- `subschema["maxItems"]?.intValue` → `subschema[key: .maxItems]?.intValue`
- `subschema["uniqueItems"]?.boolValue` → `subschema[key: .uniqueItems]?.boolValue`
- `subschema["contains"]` → `subschema[key: .contains]`
- `subschema["minContains"]?.intValue` → `subschema[key: .minContains]?.intValue`
- `subschema["maxContains"]?.intValue` → `subschema[key: .maxContains]?.intValue`

- [ ] **Step 2: Migrate `JSONSchema+Numeric.swift`**

Changes:
- `subschema["minimum"]` → `subschema[key: .minimum]`
- `subschema["maximum"]` → `subschema[key: .maximum]`
- `subschema["exclusiveMinimum"]` → `subschema[key: .exclusiveMinimum]`
- `subschema["exclusiveMaximum"]` → `subschema[key: .exclusiveMaximum]`
- `subschema["multipleOf"]` → `subschema[key: .multipleOf]`

- [ ] **Step 3: Migrate `JSONSchema+Properties.swift`**

Changes:
- `subschema["properties"]` → `subschema[key: .properties]`
- `subschema["required"]` → `subschema[key: .required]`

- [ ] **Step 4: Migrate `JSONSchema+String.swift`**

Changes:
- `subschema["pattern"]` → `subschema[key: .pattern]`
- `subschema["enum"]` → `subschema[key: .enum]`
- `subschema["const"]` → `subschema[key: .const]`
- `subschema["minLength"]` → `subschema[key: .minLength]`
- `subschema["maxLength"]` → `subschema[key: .maxLength]`

- [ ] **Step 5: Migrate `JSONSchema+Composition.swift`**

Changes:
- `subschema["allOf"]` → `subschema[key: .allOf]`
- `subschema["anyOf"]` → `subschema[key: .anyOf]`
- `subschema["oneOf"]` → `subschema[key: .oneOf]`
- `subschema["not"]` → `subschema[key: .not]`
- `subschema["if"]` → `subschema[key: .if]`
- `subschema["then"]` → `subschema[key: .then]`
- `subschema["else"]` → `subschema[key: .else]`

- [ ] **Step 6: Migrate `JSONSchema+Unevaluated.swift`**

Changes (the most per-file):
- All `subschema["..."]` → `subschema[key: .keyword]` for: `unevaluatedItems`, `unevaluatedProperties`, `prefixItems`, `items`, `contains`, `allOf`, `anyOf`, `oneOf`, `if`, `then`, `else`, `$ref`, `$dynamicRef`
- All `subschema["..."]` for `minContains`, `maxContains`, `contains`

- [ ] **Step 7: Migrate `JSONSchema+Draft7.swift`**

Changes:
- `subschema["exclusiveMinimum"]` → `subschema[key: .exclusiveMinimum]`
- `subschema["exclusiveMaximum"]` → `subschema[key: .exclusiveMaximum]`
- `subschema["minimum"]` → `subschema[key: .minimum]`
- `subschema["maximum"]` → `subschema[key: .maximum]`
- `subschema["format"]` → `subschema[key: .format]`
- `subschema["dependencies"]` → `subschema[key: .dependencies]`
- `subschema["additionalItems"]` → `subschema[key: .additionalItems]`
- `subschema["items"]` → `subschema[key: .items]`

- [ ] **Step 8: Migrate `JSONSchema+Draft202012.swift`**

Changes:
- `subschema["dependentSchemas"]` → `subschema[key: .dependentSchemas]`
- `subschema["dependentRequired"]` → `subschema[key: .dependentRequired]`
- `subschema["prefixItems"]` → `subschema[key: .prefixItems]`
- `subschema["items"]` → `subschema[key: .items]`

- [ ] **Step 9: Migrate `JSONSchema+Draft.swift`**

Changes:
- `vocabularyKeywords` type: `[String: Set<String>]` → `[String: Set<JSONSchemaKeyword>]`
- Update each value array in `vocabularyKeywords` to use enum cases
- `enabledKeywords(from:)` return type: `Set<String>?` → `Set<JSONSchemaKeyword>?`
- `metaschema["$vocabulary"]?.objectValue` → `metaschema[key: .dollarVocabulary]?.objectValue`
- `schema["$schema"]?.stringValue` → `schema[key: .dollarSchema]?.stringValue`

For the `vocabularyKeywords` dictionary, each `Set<String>` becomes `Set<JSONSchemaKeyword>`:

```swift
private static let vocabularyKeywords: [String: Set<JSONSchemaKeyword>] = [
  "https://json-schema.org/draft/2020-12/vocab/core": [
    .dollarId, .dollarSchema, .dollarRef, .dollarAnchor, .dollarDynamicRef,
    .dollarDynamicAnchor, .dollarVocabulary, .dollarComment, .dollarDefs,
  ],
  "https://json-schema.org/draft/2020-12/vocab/applicator": [
    .prefixItems, .items, .contains, .additionalProperties,
    .properties, .patternProperties, .dependentSchemas, .propertyNames,
    .if, .then, .else, .allOf, .anyOf, .oneOf, .not,
  ],
  // ... same pattern for remaining vocabularies
]
```

- [ ] **Step 10: Migrate `JSONSchema+Ref.swift`**

Changes:
- `target["$id"]?.stringValue` → `target[key: .dollarId]?.stringValue`
- `initialRef.schema["$dynamicAnchor"]?.stringValue` → `initialRef.schema[key: .dollarDynamicAnchor]?.stringValue`

Note: `target` is a `JSON` value, so we need the subscript. But `target` is already a local variable of type `JSON?`. We use `target[key: .dollarId]?.stringValue`.

- [ ] **Step 11: Migrate `JSONSchema+Patterns.swift`**

All `schema["..."]` → `schema[key: .keyword]`:
- `schema["pattern"]` → `schema[key: .pattern]`
- `schema["properties"]` → `schema[key: .properties]`
- `schema["items"]` → `schema[key: .items]`
- `schema["prefixItems"]` → `schema[key: .prefixItems]`
- `schema["not"]` → `schema[key: .not]`
- `schema["if"]` → `schema[key: .if]`
- `schema["then"]` → `schema[key: .then]`
- `schema["else"]` → `schema[key: .else]`
- `schema["patternProperties"]` → `schema[key: .patternProperties]`
- `schema["contains"]` → `schema[key: .contains]`
- `schema["additionalProperties"]` → `schema[key: .additionalProperties]`
- `schema["unevaluatedProperties"]` → `schema[key: .unevaluatedProperties]`
- `schema["additionalItems"]` → `schema[key: .additionalItems]`
- `schema["unevaluatedItems"]` → `schema[key: .unevaluatedItems]`
- `schema["propertyNames"]` → `schema[key: .propertyNames]`
- `schema["dependentSchemas"]` → `schema[key: .dependentSchemas]`
- `schema["$defs"]` → `schema[key: .dollarDefs]`

Also the iteration `for keyword in ["allOf", "anyOf", "oneOf"]` — change to use enum array:
```swift
for keyword in [JSONSchemaKeyword.allOf, .anyOf, .oneOf] {
  if let subschemas = schema[key: keyword], subschemas.isArray {
```

- [ ] **Step 12: Migrate `JSONSchemaContext.swift`**

Change `enabledKeywords` type:

Current (line 31):
```swift
var enabledKeywords: Set<String>?
```

New:
```swift
var enabledKeywords: Set<JSONSchemaKeyword>?
```

Also update the `init` and `withEnabledKeywords` methods.

- [ ] **Step 13: Run build to verify all files compile**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build 2>&1
```

- [ ] **Step 14: Commit all remaining file changes**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Sources/OrderedJSON/Schema/JSONSchema+Array.swift Sources/OrderedJSON/Schema/JSONSchema+Numeric.swift Sources/OrderedJSON/Schema/JSONSchema+Properties.swift Sources/OrderedJSON/Schema/JSONSchema+String.swift Sources/OrderedJSON/Schema/JSONSchema+Composition.swift Sources/OrderedJSON/Schema/JSONSchema+Unevaluated.swift Sources/OrderedJSON/Schema/JSONSchema+Draft7.swift Sources/OrderedJSON/Schema/JSONSchema+Draft202012.swift Sources/OrderedJSON/Schema/JSONSchema+Draft.swift Sources/OrderedJSON/Schema/JSONSchema+Ref.swift Sources/OrderedJSON/Schema/JSONSchema+Patterns.swift Sources/OrderedJSON/Schema/JSONSchemaContext.swift && git commit -m "refactor: migrate remaining schema files to typed JSONSchemaKeyword enum"
```

---

### Task 6: Add round-trip test for JSONSchemaKeyword

**Files:**
- Modify: `Tests/OrderedJSONTests/Schema/JSONSchemaCreationTests.swift`

- [ ] **Step 1: Add a test that verifies every enum case maps to a known keyword string and round-trips**

```swift
@Test func testJSONSchemaKeywordRoundTrip() {
  // Verify that every JSONSchemaKeyword case maps to a non-empty string
  // and round-trips correctly through rawValue → init.
  for keyword in JSONSchemaKeyword.allCases {
    let raw = keyword.rawValue
    #expect(!raw.isEmpty)
    let reconstructed = JSONSchemaKeyword(rawValue: raw)
    #expect(reconstructed == keyword)
  }
}

@Test func testJSONSchemaKeywordSubscript() {
  // Verify the typed subscript works correctly
  let obj: JSON = .object(["type": .string("object")])
  let val = obj[key: .type]
  #expect(val == .string("object"))
  #expect(val?.stringValue == "object")
  
  // Missing key returns nil
  let missing = obj[key: .minimum]
  #expect(missing == nil)
}

@Test func testJSONSchemaKeywordAllCasesCoverage() {
  // Verify that the validationKeywords set covers all validation-related
  // keyword cases. This is a documentation test — if a new keyword is
  // added to the enum without adding it to validationKeywords, this fails.
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
  // All enum cases that are validation-related should be in the set.
  // Annotation, meta, and content-annotation keywords are excluded.
  // This test just confirms the set matches expectations.
  #expect(allValidationKeywords.count == 40)
}
```

- [ ] **Step 2: Run tests**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift test 2>&1
```
Expected: All tests pass, including the new round-trip test.

- [ ] **Step 3: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Tests/OrderedJSONTests/Schema/JSONSchemaCreationTests.swift && git commit -m "test: add JSONSchemaKeyword round-trip and subscript tests"
```

---

### Task 7: Full build and test sweep

- [ ] **Step 1: Run full build**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build 2>&1
```

- [ ] **Step 2: Run full test suite**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift test 2>&1
```

- [ ] **Step 3: If build errors, diagnose and fix**

Common issues:
- Forgetting to convert a string-key access
- Type mismatch in set definitions
- The `keywordCache` lookup still uses `cache[key]` where `key` is now `JSONSchemaKeyword` — use `cache[key.rawValue]` instead
- The `validationKeywords.contains(key)` check needs to convert `key` (String) to `JSONSchemaKeyword` first

- [ ] **Step 4: Commit any fixes**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add -A && git commit -m "fix: address build and test issues from keyword enum migration"
```

---

### Task 8: Final verification

- [ ] **Step 1: Run final build + test**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build && swift test 2>&1
```

- [ ] **Step 2: Verify no raw string keyword accesses remain in schema source files**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && grep -rn 'subschema\["' Sources/OrderedJSON/Schema/ | wc -l
```
Expected: 0

```bash
grep -rn 'schema\["' Sources/OrderedJSON/Schema/ | wc -l
```
Expected: 0 (except for `schemaJSON` and other non-keyword uses)

- [ ] **Step 3: Verify the diff is clean and complete**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git diff --stat
```
Review the changed files count matches expectations (15 source files + 1 test file).

- [ ] **Step 4: Print summary**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && echo "Migration complete. All JSON Schema keyword accesses now use typed enum."
```
