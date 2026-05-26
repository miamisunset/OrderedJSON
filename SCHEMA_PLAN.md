# JSON Schema Support — Implementation Plan

**Target: Draft 2020-12 (primary) + Draft 7 (backward compat)**
**Branch: `json-schema-support`**

## Architecture

```
Sources/OrderedJSON/Schema/
├── JSONSchema.swift          — Schema type, draft enum, factory, validate()
├── JSONSchemaError.swift     — Error types per keyword
├── JSONSchemaResult.swift    — Validation result struct
├── JSONSchemaKeyword.swift   — Keyword parsing & compilation
├── JSONSchemaRef.swift       — $ref / $defs / $dynamicRef resolution
├── JSONSchemaFormat.swift    — Format validation (date-time, email, uuid, etc.)
├── JSONSchemaOutput.swift    — Output modes (basic/verbose)
├── JSONSchemaGeneration.swift— Schema generation from JSON instances (bonus)
└── JSONSchemaValidator.swift — Compiled validation engine
```

Tests: `Tests/OrderedJSONTests/Schema/JSONSchemaTests.swift`

---

## Phase 1 — Core Type + Basic Validation Keywords

**Goal**: `JSONSchema` type that validates the most common keywords.

### Deliverables

| File | What |
|------|------|
| `JSONSchema.swift` | `JSONSchema` struct, `JSONSchemaDraft` enum |
| `JSONSchemaError.swift` | `JSONSchemaError` with `.validationError(path: String, keyword: String, message: String)` |
| `JSONSchemaResult.swift` | `JSONSchemaResult { valid: Bool, errors: [JSONSchemaError] }` |
| `JSONSchemaValidator.swift` | Initial validation engine (Phase 1 keywords only) |
| `JSONSchemaTests.swift` | Tests for each keyword |

### Keywords (Phase 1)

- `type` — string or array of strings: `"null"`, `"boolean"`, `"object"`, `"array"`, `"number"`, `"string"`, `"integer"`
- `properties` — object per-key subschema, validates matching keys in data
- `required` — array of required property names
- `minimum` / `maximum` / `exclusiveMinimum` / `exclusiveMaximum` — numeric bounds
- `multipleOf` — numeric divisibility
- `pattern` — regex match on string values
- `enum` — array of allowed values (deep equality)
- `const` — exact value match

### API

```swift
let schema = try JSONSchema(schema: schemaJSON, draft: .draft202012)
let result = schema.validate(document)
result.valid        // Bool
result.errors       // [JSONSchemaError]

// Convenience
schema.validate(document) throws -> Bool  // throws first error
schema.validates(document) -> Bool        // non-throwing bool check
```

### Draft detection

`JSONSchemaDraft.auto` reads `$schema` from the schema JSON:
- `http://json-schema.org/draft-07/schema#` → `.draft7`
- `https://json-schema.org/draft/2020-12/schema` → `.draft202012`
- No `$schema` → `.draft202012` (default)

---

## Phase 2 — Composition Keywords

**Goal**: Boolean logic keywords for schema composition.

### Keywords

- `allOf` — all subschemas must validate
- `anyOf` — at least one subschema must validate
- `oneOf` — exactly one subschema must validate
- `not` — subschema must NOT validate
- `if` / `then` / `else` — conditional validation (Draft 7+)
- `dependentSchemas` — schema required when certain keys present (2020-12)
- `dependentRequired` — keys required when certain keys present

### Complexity

- `oneOf` needs to count matches, not short-circuit
- `if`/`then`/`else` only applies when `if` validates (Draft 7 behavior) — but in 2020-12, it's "if validates, then must validate then; else must validate else"
- Error messages need to show which subschema failed

---

## Phase 3 — Array & Object Keywords (✅ Complete)

**Branch**: `phase-3-array-object-keywords-v2`
**PR**: [#31](https://github.com/miamisunset/OrderedJSON/pull/31)

**Goal**: Array and object structural validation.

### Keywords implemented

| Keyword | Draft 7 | Draft 2020-12 | Status |
|---------|---------|---------------|--------|
| `items` | Schema (all items) or array (tuple) | Schema (all items, non-tuple) | ✅ |
| `prefixItems` | — | Tuple validation for first N items | ✅ |
| `additionalItems` | Schema for items beyond tuple | — | ✅ |
| `minItems` / `maxItems` | Array length bounds | Same | ✅ |
| `uniqueItems` | All elements must be unique | Same | ✅ |
| `contains` | At least one item matches subschema | Same | ✅ |
| `minProperties` / `maxProperties` | Object size bounds | Same | ✅ |
| `propertyNames` | Schema for each key name | Same | ✅ |
| `patternProperties` | Schema for keys matching regex | Same | ✅ |
| `additionalProperties` | Schema for keys not covered | — | ✅ |
| `unevaluatedProperties` | — | Schema for keys not evaluated | ✅ |
| `unevaluatedItems` | — | Schema for items not evaluated | ✅ |

### Source refactoring (merged in PR #31)

Split `JSONSchema.swift` (1184 lines) into:
- `JSONSchema.swift` (~300 lines) — core struct, draft, API, schemaEqual
- `JSONSchemaValidators.swift` (~625 lines) — all keyword validators
- `JSONSchemaPatterns.swift` (~82 lines) — init-time regex traversal

Test file `JSONSchemaTests.swift` (1476 lines) split into:
- `JSONSchemaCoreTests.swift` (~419 lines)
- `JSONSchemaKeywordTests.swift` (~887 lines)

### Known deviations
- `additionalProperties`/`unevaluatedProperties` with boolean `false` produce error keyword `"false"` (from the boolean subschema), not the keyword name — consistent with general boolean schema behavior
- `patternProperties` regex key validation throws at init time for invalid regex patterns
- `unevaluatedItems` does not honor `items` (schema mode) or `contains` match indices — items evaluated by those keywords are not excluded; tracked as deviation tests
- `unevaluatedProperties` does not track evaluation from `additionalProperties` or in-place applicators (`allOf`/`anyOf`/`oneOf`/`if`/`then`/`else`) — tracked as deviation tests
- `contains` lacks `minContains`/`maxContains` support (Draft 2020-12 extension) — `contains` returns on first match
- `$ref` sibling-keyword semantics: Draft 2019-09+ allows annotations alongside `$ref`; current impl short-circuits all sibling keywords (safe default, deviating from latest spec)
- `$ref` cycle detection uses recursion depth limit (100) rather than pointer-set tracking — catches cycles but keyword is `"schema"` not `"$ref"`
- External `$ref` (remote URIs) not supported — only local `#` pointers
- `$dynamicRef`/`$dynamicAnchor` not implemented
- `$defs` for Draft 7 (`definitions` keyword) not supported
- `$anchor` declared on inner subschemas not collected — only root-level `$anchor` is parsed
- `$defs` declared on inner subschemas not collected — only root-level `$defs` is parsed
- `$ref` cycle detection: current depth-limit approach could be improved to track an in-flight set of ref pointers for better diagnostics (keyword: `"schema"` vs `"$ref"`)

---

## Phase 4a — `$ref` Resolution + `$defs` + `$id`/`$anchor` (✅ Complete)

**Branch**: `phase-4-ref-resolution`
**PR**: [#33](https://github.com/miamisunset/OrderedJSON/pull/33)

### What shipped
- `CompiledSchema` struct — parses `$defs`, `$id`, `$anchor` at init time
- `$ref` resolution — resolves local JSON Pointer references (`#`, `#/$defs/name`) at validation time
- `JSON.resolve(_:)` — RFC 6901 JSON Pointer implementation
- `$comment` — ignored during validation
- Unresolvable `$ref` produces validation error
- 25 tests, 194 total schema tests

### Known limitations (deferred to Phase 4b)
- External `$ref` (remote URIs) not supported
- `$dynamicRef`/`$dynamicAnchor` not implemented
- `$id` used for base URI extraction but not for URI resolution
- Schema compilation (keyword tree) deferred — `$ref` resolved at validation time
- `$defs` for Draft 7 (`definitions` keyword) not supported

---

## Phase 4b — `$dynamicRef`/`$dynamicAnchor`, External `$ref`, Schema Compilation

## Phase 5 — Format Validation

**Goal**: Validate string formats.

### Formats

| Format | Validation |
|--------|-----------|
| `date-time` | RFC 3339 / ISO 8601 |
| `date` | RFC 3339 date |
| `time` | RFC 3339 time |
| `duration` | ISO 8601 duration |
| `email` | Basic email regex |
| `hostname` | RFC 1034 hostname |
| `ipv4` | IPv4 address |
| `ipv6` | IPv6 address |
| `uuid` | UUID format |
| `uri` | RFC 3986 URI |
| `uri-reference` | URI or relative reference |
| `json-pointer` | RFC 6901 JSON Pointer |
| `regex` | Valid regex pattern |
| `date-time` | ISO 8601 with timezone |

### Configurable

`JSONSchemaFormatOptions` to enable/disable specific formats:
```swift
var formatOptions = JSONSchemaFormatOptions()
formatOptions.enabledFormats = .all
formatOptions.disabledFormats = [.regex, .json-pointer]
```

---

## Phase 6 — String Content Keywords

**Goal**: String length and content validation.

### Keywords

- `minLength` / `maxLength` — character count bounds (Swift `String.count`)
- `contentMediaType` — media type annotation (2020-12 annotation only, not assertion)
- `contentEncoding` — encoding annotation
- `contentSchema` — schema for decoded content

---

## Phase 7 — Output & Error Reporting

**Goal**: Rich error messages with schema path tracking.

### Output modes

- **Basic** (default): flat list of errors with path, keyword, message
- **Verbose**: hierarchical errors showing which schema keyword failed at which path

### Error detail

```swift
struct JSONSchemaError: Error, Hashable, Sendable {
    let instancePath: String      // JSON Pointer to the failing value
    let schemaPath: String        // JSON Pointer into the schema
    let keyword: String           // e.g. "type", "minimum", "required"
    let message: String           // Human-readable message
    let failedValue: JSON?        // The value that failed (optional)
    let parentSchema: JSON?       // The schema that produced this error (optional)
}
```

---

## Phase 8 — JSON Schema Test Suite Integration

**Goal**: Pass the official JSON Schema Test Suite.

### Test suite

The official test suite at https://github.com/json-schema-org/JSON-Schema-Test-Suite contains:
- Draft 4 tests
- Draft 7 tests  
- Draft 2019-09 tests
- Draft 2020-12 tests
- Optional tests (format, etc.)

### Approach

- Fetch the test suite as a submodule or download
- Write a script that runs each test case against our validator
- Track pass/fail per keyword
- Fix discrepancies

### Target

- 100% pass on Draft 2020-12 required keywords
- 100% pass on Draft 7 required keywords
- Format tests: as many as feasible (some formats are complex)

---

## Phase 9 — Schema Generation (bonus)

**Goal**: Infer a JSON Schema from a JSON instance.

### API

```swift
let schema = document.schema()  // → JSONSchema
```

### Inference rules

- `null` → `{"type": "null"}`
- `boolean` → `{"type": "boolean"}`
- `integer` → `{"type": "integer"}`
- `float` → `{"type": "number"}`
- `string` → `{"type": "string"}`
- `array` → `{"type": "array", "items": <schema of elements>}` or `{"type": "array", "prefixItems": [...]}` if heterogeneous
- `object` → `{"type": "object", "properties": {...}, "required": [...]}`

### Use case

Quick schema generation for debugging or documentation.

---

## Phase 10 — Performance Optimization

**Goal**: Fast validation through compiled schemas and caching.

### Optimizations

- **Compiled keyword tree**: Pre-parse schema into keyword nodes at init time, not during validation
- **Cached `$ref` resolution**: Resolve once, reuse
- **Short-circuit**: `allOf`/`anyOf`/`if` short-circuit when possible
- **Property whitelist**: Pre-compute which properties are covered by `properties`/`patternProperties` for `additionalProperties`/`unevaluatedProperties` checks
- **Regex pre-compilation**: Compile `pattern`/`patternProperties` regexes at init time

---

## Dependency considerations

JSON Schema validation needs:
- `Foundation` — already available (used for Codable, format validation)
- `Foundation` `NSRegularExpression` — for `pattern` keyword
- No new package dependencies needed

---

## Test strategy

- **Unit tests**: Every keyword gets dedicated test cases (valid + invalid)
- **Edge cases**: Empty schemas, `{"type": []}`, `{"allOf": []}`, recursive `$ref`, cycle detection
- **Draft-specific tests**: Same schema under Draft 7 vs Draft 2020-12
- **Round-trip**: Generate schema from instance → validate instance → passes
- **Test suite**: Official JSON Schema Test Suite integration in Phase 8

---

## Timeline estimate

| Phase | Keywords | Tests | Relative Effort |
|-------|----------|-------|-----------------|
| 1 — Core + Basic | 11 | ~40 | Medium |
| 2 — Composition | 7 | ~30 | Medium |
| 3 — Array/Object | 14 | ~50 | Large |
| 4 — `$ref` + Compilation | 6 | ~30 | Large |
| 5 — Format | 15 | ~30 | Medium |
| 6 — String Content | 5 | ~10 | Small |
| 7 — Output/Errors | — | ~15 | Small |
| 8 — Test Suite | — | ~100 | Medium |
| 9 — Generation | — | ~15 | Small |
| 10 — Performance | — | ~10 | Medium |

---

## Known Deviations (Phase 1)

### 1. Regex flavor: ICU vs ECMA-262
JSON Schema spec mandates ECMA-262 regex syntax. Our validator uses Foundation's `NSRegularExpression` (ICU engine). ICU and ECMA-262 differ on:
- Unicode awareness (`\d` matches Unicode digits in ICU, ASCII only in ECMA-262)
- Lookbehind support (ICU supports lookbehind, ECMA-262 limited)
- Named capture syntax

Will be addressed in Phase 5/8 (Test Suite integration) when running the official JSON-Schema-Test-Suite.

### 2. Boolean schemas (resolved in Phase 2)
Draft 2020-12 allows `true` (accept everything) and `false` (reject everything) as schemas. Supported since Phase 2 (composition keywords). The error keyword for false schemas is `"false"` (the literal value), chosen for debuggability over `"boolean"`.

### 3. `required` semantics (spec-compliant as of review fix)
`required` checks only key *presence*, not value. An explicit `null` satisfies `required`. This is now correctly implemented.

### 4. `exclusiveMinimum`/`exclusiveMaximum` Draft 7 semantics
Draft 7 uses these as boolean modifiers on `minimum`/`maximum`. Draft 2020-12 uses them as numeric exclusive bounds. Both are correctly supported via the `draft` parameter.

### 5. String length: code points vs grapheme clusters
`minLength`/`maxLength` use `unicodeScalars.count` (code points per RFC 8259). Grapheme clusters (e.g. emoji sequences) may have multiple code points but count as 1 grapheme. This is spec-compliant.

### 6. Schema compilation
Currently the schema JSON is held as-is and walked on each `validate()` call. Pattern regexes are pre-compiled at init time. Full compiled keyword tree optimization is deferred to Phase 4/10.

### 6. Output format
Phase 1 uses a flat error list (`JSONSchemaResult.errors`). The official JSON Schema Output Format (basic/verbose) will be implemented in Phase 7.
