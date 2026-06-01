# JSON Schema Error Keyword Typed Refactoring

## Overview

Following the migration of raw string schema keywords to the typed `JSONSchemaKeyword` enum (PR #52), this work completes the refactoring by:

1. Changing `JSONSchemaError.keyword` from `String` to `JSONSchemaKeyword`
2. Adding `falseSchema` and `schemaError` cases for special error categories
3. Updating all error creation sites and test assertions

## Changes

### 1. `JSONSchemaKeyword` enum — two new cases

Add to `JSONSchema+Shared.swift`:

```swift
/// Boolean `false` schema — rejects all values
case falseSchema = "false"

/// Generic schema validation error (recursion, invalid structure, etc.)
case schemaError = "schema"
```

### 2. `JSONSchemaError.keyword` — type change

In `JSONSchemaError.swift`:

```swift
// Before
public let keyword: String
init(..., keyword: String, ...)

// After
public let keyword: JSONSchemaKeyword
init(..., keyword: JSONSchemaKeyword, ...)
```

The `description` property uses `keyword.rawValue` to maintain the same output format.

### 3. Error creation sites — update keyword arguments

Replace `keyword: "keywordName"` with `keyword: .keywordName` in all validation files:

| Source File | Sites | Keywords |
|---|---|---|
| `JSONSchema.swift` | 1 | `.schemaError` |
| `JSONSchema+Array.swift` | 4 | `.minItems`, `.maxItems`, `.uniqueItems`, `.contains` |
| `JSONSchema+Composition.swift` | 6 | `.allOf`, `.anyOf`, `.oneOf`, `.not`, `.then`, `.else` |
| `JSONSchema+Compilation.swift` | 3 | `.dollarId`, `.dollarAnchor`, `.dollarDynamicAnchor` |
| `JSONSchema+Draft202012.swift` | 2 | `.dependentSchemas`, `.dependentRequired` |
| `JSONSchema+Draft7.swift` | 6 | `.exclusiveMinimum`, `.exclusiveMaximum`, `.format`, `.dependencies` |
| `JSONSchema+Numeric.swift` | 8 | `.minimum`, `.maximum`, `.exclusiveMinimum`, `.exclusiveMaximum`, `.multipleOf` |
| `JSONSchema+Object.swift` | 3 | `.minProperties`, `.maxProperties`, `.propertyNames` |
| `JSONSchema+Patterns.swift` | 2 | `.pattern`, `.patternProperties` |
| `JSONSchema+Properties.swift` | 2 | `.required` |
| `JSONSchema+String.swift` | 5 | `.pattern`, `.enum`, `.const`, `.minLength`, `.maxLength` |
| `JSONSchema+Type.swift` | 2 | `.type` |
| `JSONSchema+Unevaluated.swift` | 2 | `.minContains`, `.maxContains` |
| `JSONSchema+Validation.swift` | 4 | `.falseSchema`, `.schemaError`, `.dollarDynamicRef`, `.dollarRef` |

### 4. Test file updates

Replace string literal comparisons with enum comparisons in ~70 assertions across ~15 test files. The key path syntax `\.keyword` in `map(\.keyword)` will need to change to closure form `{ $0.keyword }` since `JSONSchemaKeyword` conforms to `Equatable` but keypath extraction of an enum member may not work with the existing string-based keypath usage.

### 5. `JSONSchemaGeneration.swift` — no changes

Left as-is. The string keys in JSON object construction are correct JSON format behavior and are not code-level identifiers.

### Backward compatibility

- `description` uses `keyword.rawValue` so error messages remain unchanged
- Callers checking `keyword == ""` or `keyword != ""` will need to update (no empty-string keyword exists in the enum; use optional or `.rawValue` checks)
- `JSONSchemaError` initializer changes parameter type from `String` to `JSONSchemaKeyword` — source-breaking but mechanically replaceable
