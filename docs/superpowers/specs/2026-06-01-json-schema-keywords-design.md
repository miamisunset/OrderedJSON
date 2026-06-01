# JSON Schema Keyword Typed Enum Design

## Problem

JSON Schema keywords are accessed as raw string literals throughout the codebase:

```swift
subschema["type"]
subschema["properties"]
subschema["minimum"]
subschema["$ref"]
```

This is error-prone: typos are caught only at runtime, there's no autocomplete for keyword names, and keyword names are duplicated across multiple data structures (`validationKeywords`, `vocabularyKeywords`, `subschemaKeywords`).

## Solution

A `JSONSchemaKeyword` enum backed by raw strings, with a custom subscript overload on `JSON` so call sites become:

```swift
subschema[key: .type]
subschema[key: .properties]
subschema[key: .minimum]
subschema[key: .dollarRef]
```

## Enum Definition

```swift
public enum JSONSchemaKeyword: String, Hashable, Sendable, CaseIterable {
  // Meta-keywords (dollar-prefixed → camelCase with "dollar" prefix)
  case dollarId = "$id"
  case dollarRef = "$ref"
  case dollarDefs = "$defs"
  case dollarAnchor = "$anchor"
  case dollarDynamicAnchor = "$dynamicAnchor"
  case dollarDynamicRef = "$dynamicRef"
  case dollarSchema = "$schema"
  case dollarVocabulary = "$vocabulary"
  case dollarComment = "$comment"

  // Validation keywords
  case type
  case `const`        // "const" — backtick needed (Swift reserved word)
  case `enum`         // "enum"  — backtick needed
  case multipleOf
  case maximum
  case exclusiveMaximum
  case minimum
  case exclusiveMinimum
  case maxLength
  case minLength
  case pattern
  case format
  case maxItems
  case minItems
  case uniqueItems
  case maxContains
  case minContains
  case maxProperties
  case minProperties
  case required
  case dependentRequired

  // Applicator keywords
  case properties
  case patternProperties
  case additionalProperties
  case propertyNames
  case dependentSchemas
  case items
  case prefixItems
  case additionalItems
  case unevaluatedItems
  case unevaluatedProperties
  case contains
  case allOf
  case anyOf
  case oneOf
  case not
  case `if`            // "if" — backtick needed
  case `then`          // "then" — backtick needed
  case `else`          // "else" — backtick needed

  // Content keywords
  case contentMediaType
  case contentEncoding
  case contentSchema

  // Annotation keywords
  case title
  case description
  case `default`       // "default" — backtick needed
  case examples
  case readOnly
  case writeOnly
  case deprecated
}
```

## JSON Subscript Overload

```swift
extension JSON {
  subscript(key schemaKeyword: JSONSchemaKeyword) -> JSON? {
    self[schemaKeyword.rawValue]
  }
}
```

## Type Changes

### 1. `validationKeywords` (JSONSchema+Validation.swift)
- Current: `private static let validationKeywords: Set<String> = [...]`
- New: `private static let validationKeywords: Set<JSONSchemaKeyword> = [...]`

### 2. `vocabularyKeywords` (JSONSchema+Draft.swift)
- Current: `private static let vocabularyKeywords: [String: Set<String>] = [...]`
- New: `private static let vocabularyKeywords: [String: Set<JSONSchemaKeyword>] = [...]`

### 3. `subschemaKeywords` (JSONSchema+Compilation.swift)
- Current: `private static let subschemaKeywords: [String] = [...]`
- New: `private static let subschemaKeywords: [JSONSchemaKeyword] = [...]`

### 4. `keyword()` function (JSONSchema+Validation.swift)
- Current: `func keyword(_ key: String, from subschema: JSON, at pointer: String) -> JSON?`
- New: `func keyword(_ key: JSONSchemaKeyword, from subschema: JSON, at pointer: String) -> JSON?`

### 5. `keywordEnabled()` closure (JSONSchema+Validation.swift)
- Current: `func keywordEnabled(_ kw: String) -> Bool`
- New: `func keywordEnabled(_ kw: JSONSchemaKeyword) -> Bool`

### 6. `enabledKeywords` in EvaluationContext
- Current: `var enabledKeywords: Set<String>?`
- New: `var enabledKeywords: Set<JSONSchemaKeyword>?`

### 7. `enabledKeywords(from:)` (JSONSchema+Draft.swift)
- Current: `package static func enabledKeywords(from metaschema: JSON) -> Set<String>?`
- New: `package static func enabledKeywords(from metaschema: JSON) -> Set<JSONSchemaKeyword>?`

## Call Site Migration

Every `subschema["keyword"]` becomes `subschema[key: .keyword]`:

**Patterns found in the codebase:**

| Current | New |
|---------|-----|
| `subschema["type"]` | `subschema[key: .type]` |
| `subschema["properties"]` | `subschema[key: .properties]` |
| `subschema["required"]` | `subschema[key: .required]` |
| `subschema["minimum"]` | `subschema[key: .minimum]` |
| `subschema["maximum"]` | `subschema[key: .maximum]` |
| `subschema["pattern"]` | `subschema[key: .pattern]` |
| `subschema["enum"]` | `subschema[key: .enum]` |
| `subschema["const"]` | `subschema[key: .const]` |
| `subschema["$ref"]` | `subschema[key: .dollarRef]` |
| `subschema["$id"]` | `subschema[key: .dollarId]` |
| `subschema["$defs"]` | `subschema[key: .dollarDefs]` |
| `subschema["$anchor"]` | `subschema[key: .dollarAnchor]` |
| `subschema["$dynamicAnchor"]` | `subschema[key: .dollarDynamicAnchor]` |
| `subschema["$dynamicRef"]` | `subschema[key: .dollarDynamicRef]` |
| `subschema["$schema"]` | `subschema[key: .dollarSchema]` |
| `subschema["$vocabulary"]` | `subschema[key: .dollarVocabulary]` |
| `subschema["$comment"]` | `subschema[key: .dollarComment]` |
| `subschema["allOf"]` | `subschema[key: .allOf]` |
| `subschema["anyOf"]` | `subschema[key: .anyOf]` |
| `subschema["oneOf"]` | `subschema[key: .oneOf]` |
| `subschema["not"]` | `subschema[key: .not]` |
| `subschema["if"]` | `subschema[key: .if]` |
| `subschema["then"]` | `subschema[key: .then]` |
| `subschema["else"]` | `subschema[key: .else]` |
| `subschema["items"]` | `subschema[key: .items]` |
| `subschema["prefixItems"]` | `subschema[key: .prefixItems]` |
| `subschema["contains"]` | `subschema[key: .contains]` |
| `subschema["minItems"]` | `subschema[key: .minItems]` |
| `subschema["maxItems"]` | `subschema[key: .maxItems]` |
| `subschema["uniqueItems"]` | `subschema[key: .uniqueItems]` |
| `subschema["minLength"]` | `subschema[key: .minLength]` |
| `subschema["maxLength"]` | `subschema[key: .maxLength]` |
| `subschema["minProperties"]` | `subschema[key: .minProperties]` |
| `subschema["maxProperties"]` | `subschema[key: .maxProperties]` |
| `subschema["propertyNames"]` | `subschema[key: .propertyNames]` |
| `subschema["patternProperties"]` | `subschema[key: .patternProperties]` |
| `subschema["additionalProperties"]` | `subschema[key: .additionalProperties]` |
| `subschema["additionalItems"]` | `subschema[key: .additionalItems]` |
| `subschema["dependentSchemas"]` | `subschema[key: .dependentSchemas]` |
| `subschema["dependentRequired"]` | `subschema[key: .dependentRequired]` |
| `subschema["unevaluatedItems"]` | `subschema[key: .unevaluatedItems]` |
| `subschema["unevaluatedProperties"]` | `subschema[key: .unevaluatedProperties]` |
| `subschema["exclusiveMinimum"]` | `subschema[key: .exclusiveMinimum]` |
| `subschema["exclusiveMaximum"]` | `subschema[key: .exclusiveMaximum]` |
| `subschema["multipleOf"]` | `subschema[key: .multipleOf]` |
| `subschema["format"]` | `subschema[key: .format]` |
| `subschema["dependencies"]` | `subschema[key: .dependencies]` |
| `subschema["contentMediaType"]` | `subschema[key: .contentMediaType]` |
| `subschema["contentEncoding"]` | `subschema[key: .contentEncoding]` |
| `subschema["contentSchema"]` | `subschema[key: .contentSchema]` |
| `subschema["minContains"]` | `subschema[key: .minContains]` |
| `subschema["maxContains"]` | `subschema[key: .maxContains]` |
| `subschema["title"]` | `subschema[key: .title]` |
| `subschema["description"]` | `subschema[key: .description]` |
| `subschema["default"]` | `subschema[key: .default]` |
| `subschema["examples"]` | `subschema[key: .examples]` |
| `subschema["readOnly"]` | `subschema[key: .readOnly]` |
| `subschema["writeOnly"]` | `subschema[key: .writeOnly]` |
| `subschema["deprecated"]` | `subschema[key: .deprecated]` |

## Keyword Cache

The keyword cache in `CompiledSchema` currently stores `[String: JSON]` dictionaries per pointer. Since the cache is built from schema JSON keys (which are strings), and the `keyword()` function accepts the typed enum, the cache lookup needs to convert:

```swift
func keyword(_ key: JSONSchemaKeyword, from subschema: JSON, at pointer: String) -> JSON? {
  if let cache = compiled?.keywordCache[pointer], let v = cache[key.rawValue] {
    return v
  }
  return subschema[key: key]
}
```

## Files Touched

### Source files (15 files):
1. `JSONSchema+Shared.swift` — enum definition, JSON subscript extension
2. `JSONSchema+Compilation.swift` — `subschemaKeywords` type, `keywordCache` type
3. `JSONSchema+Validation.swift` — `validationKeywords`, `keyword()`, `keywordEnabled()`, switch cases
4. `JSONSchema+Object.swift` — call sites
5. `JSONSchema+Array.swift` — call sites
6. `JSONSchema+Numeric.swift` — call sites
7. `JSONSchema+Properties.swift` — call sites
8. `JSONSchema+String.swift` — call sites
9. `JSONSchema+Composition.swift` — call sites
10. `JSONSchema+Unevaluated.swift` — call sites
11. `JSONSchema+Draft7.swift` — call sites
12. `JSONSchema+Draft202012.swift` — call sites
13. `JSONSchema+Draft.swift` — `vocabularyKeywords` type, `enabledKeywords()` return type
14. `JSONSchema+Ref.swift` — call sites (`$id`, `$dynamicAnchor`, `$ref`)
15. `JSONSchemaContext.swift` — `enabledKeywords` type

### Test files:
No test changes needed — tests construct schemas via `JSON.object([...])`, not via the typed subscript. Optionally add a test verifying all enum cases round-trip correctly.

## Error Messages

Error messages remain as string literals (e.g., `keyword: "type"` in `JSONSchemaError`). These are user-facing and should stay readable. No enum mapping needed.

## Migration Strategy

Single-pass migration: define the enum + subscript, then sweep all 15 source files in one commit. No partial-migration intermediate state.
