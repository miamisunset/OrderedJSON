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

## Phase 4b — `$dynamicRef`/`$dynamicAnchor` (✅ Complete)

**PR**: [#34](https://github.com/miamisunset/OrderedJSON/pull/34)

### What shipped
- `$dynamicAnchor` parsed at init into `CompiledSchema.dynamicAnchors`
- `$dynamicRef` resolved against dynamic scope stack at validation time
- Dynamic scope propagates through ALL keyword validators
- Recursion depth tracking propagates through ALL keyword validators
- Tuple scope frames (`[(String, JSON)]`) instead of `[OrderedDictionary<String, JSON>]`
- Self-reference guard removed — depth guard handles cycles
- `maxRecursionDepth` set to 20 (conservative)
- Internal validators require explicit `recursionDepth: Int` (no default)
- 6 tests, 194 total schema tests

### Bug fix: depth tracking through validators
The `recursionDepth` parameter had a default of `0`, so every validator call that invoked `validateValue` reset depth tracking. Composition keywords and property validators called `validateValue` with depth=0, defeating the recursion guard and causing stack overflow. Fixed by threading `recursionDepth` and `dynamicScope` through all 34 validator call sites.

### Deviations updated
- Self-reference guard removed — no longer a deviation
- Dynamic scope propagation — no longer a deviation
- Recursive schemas work — canonical `$defs/node` pattern passes

---

## Phase 4c — Nested Annotation Collection (✅ Complete)

**PR**: [#35](https://github.com/miamisunset/OrderedJSON/pull/35)

### What shipped
- Schema tree walk (`collectAnnotationsRecursive`) visits 18+ subschema locations
- Nested `$defs`, `$anchor`, `$dynamicAnchor` collection from all levels
- `resolveRef` handles `#/$defs/<key>/<tail>` deep pointers with RFC 6901 unescaping
- `CompiledSchema.init` throws on duplicate anchors
- `guard case .object` → `if case` with `preconditionFailure`
- 18 new tests, 212 total schema tests

### Deviations documented
- Flat `$defs` collection (per-resource scoping deferred to Phase 4d)
- `$id` scoping prerequisite deferred
- Boolean schemas never contain annotations

### Remaining (deferred to Phase 4d)
- External `$ref` (URIs without `#` fragment)
- `$id` scoping — per-resource anchor/`$defs` tables
- Full schema compilation keyword tree

---

## Phase 4d — `$id` Scoping (✅ Merged, PR #36)

### What shipped
- `ResourceScope` struct with per-`$id` annotation tables (`anchors`, `dynamicAnchors`, `defs`, `scopeSchema`)
- `collectResourcesRecursive` groups annotations by base URI, throws on duplicate `$id`
- `resolveRef` splits on `#`, resolves against appropriate resource scope via `currentResourceURI`
- `resolveDynamicRef` consults current resource's `dynamicAnchors`/`anchors` (not just root)
- `currentResourceURI: String` threaded through `validateValue` and all 34 keyword validators
- `scopeSchema: JSON` on `ResourceScope` for correct JSON Pointer fallback
- `CompiledSchema.resources["baseURI"]` replaces flat dicts
- `CompiledSchema.rootResource(_:)` helper
- 218 schema tests — all passing, lint clean

### Review outcomes (10 items addressed)
- #1 `$ref` from embedded resource resolves to that resource's scope (not root)
- #2 External pointer fallback resolves against `resource.scopeSchema` (not root `schemaJSON`)
- #3 `resolveDynamicRef` consults current resource's `dynamicAnchors`/`anchors`
- #4 Relative `$id` resolution deferred in Known Limitations
- #5 Duplicate `$id` throws at init (consistent with duplicate-anchor handling)
- #6 Empty-string sentinel documented as collision risk
- #7 Dead ternary branch removed
- #8 Bare URI ref TODO added pointing at Phase 4e
- #9 Test docstring updated
- #10 `rootResource` helper added to cut noise

### Remaining (deferred to Phase 4e)
- External `$ref` (URIs without local resource match)
- Schema compilation keyword tree
- `$dynamicRef` resource-scope awareness
- `EvaluationContext` struct to bundle `(recursionDepth, currentResourceURI, dynamicScope)`
- Relative `$id` resolution (RFC 3986 join helper)
- Cross-resource anchor isolation negative test
- External-pointer-with-tail test (`/a#/properties/x`)
- External-resource loading with resolver callback

---

## Phase 4e — External `$ref`, Keyword Tree Compilation, `$dynamicRef` Resource Scoping (branch `phase-4e-external-ref-compilation`)

### Completed
- **EvaluationContext struct** — bundles `(recursionDepth, currentResourceURI, dynamicScope)` into a single struct, threaded through all 34 keyword validators and 19 `validateValue` call sites. Eliminates footgun pattern of defaulted parameters.
- **Relative `$id` resolution (RFC 3986)** — `resolveRelativeID` helper joins nested `$id` values against parent base URI.
- **Bare URI `$ref`** — `resolveRef` handles pointers without `#` fragment.
- **`$dynamicRef` resource-scope fallback** — consults `resources[currentResourceURI].dynamicAnchors`.
- **Review fixes applied** — dropped `ctx: EvaluationContext = EvaluationContext()` defaults from all internal validators, added `DynamicAnchorFrame` struct, fixed `"defs"`→`$defs` typo, added `preconditionFailure` in unreachable split branch, added negative bare-URI test, pinned `crossResourceAnchorIsolation` error keyword.

### Remaining (deferred)
- Keyword tree compilation (performance)
- External-resource loading with resolver callback

### Tests
- 10 new tests, 228 total schema tests — all passing, lint clean

---

## Phase 5 — Format Validation (branch `phase-5-format-validation`)

**Goal**: Validate string formats.

### Completed

| Format | Validation | Foundation API Used |
|--------|-----------|-------------------|
| `date-time` | RFC 3339 / ISO 8601 | `ISO8601DateFormatter` (with/without fractional fallback) |
| `date` | RFC 3339 date | Regex + month-aware day range check |
| `time` | RFC 3339 time | Regex + range check |
| `duration` | ISO 8601 duration | Regex-based parser |
| `email` | Basic email regex | Regex (`^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$`) |
| `hostname` | RFC 1034 hostname | Regex (URL host parsing inconsistent for edge cases) |
| `ipv4` | IPv4 address | `inet_pton` (POSIX standard API) |
| `ipv6` | IPv6 address | `inet_pton` (POSIX standard API) |
| `uuid` | UUID format | `UUID(uuidString:)` |
| `uri` | RFC 3986 URI | `URL` with scheme + host check |
| `uri-reference` | URI or relative reference | `URL` (any valid URL) |
| `json-pointer` | RFC 6901 JSON Pointer | Custom check (empty or starts with `/`) |
| `regex` | Valid regex pattern | `NSRegularExpression` (compilation check) |

### Configurable

`JSONSchemaFormatOptions` with `FormatSet` bitmask on `JSONSchema`:
```swift
var opts = JSONSchemaFormatOptions()
opts.disable(.regex)
schema.formatOptions = opts
```

### Files changed
- `Sources/OrderedJSON/Schema/JSONSchemaFormat.swift` (new) — 13 format validators
- `Sources/OrderedJSON/Schema/JSONSchemaFormatOptions.swift` (new) — options struct + FormatSet bitmask
- `Sources/OrderedJSON/Schema/JSONSchema.swift` — formatOptions property set at init
- `Sources/OrderedJSON/Schema/JSONSchemaValidators.swift` — validateFormat with draft-aware assertion
- `Tests/OrderedJSONTests/Schema/JSONSchemaKeywordTests.swift` — format tests

### Tests
- 30+ format tests covering valid/invalid for all 13 formats, plus edge cases
- 258+ total schema tests — all passing, lint clean

---

## Phase 6 — String Content Keywords (✅ Complete)

**Branch**: `phase-6-json-schema-draft-compat`

**Goal**: String length and content validation.

### Keywords (all implemented)

- `minLength` / `maxLength` — character count bounds (Swift `String.count`), already implemented in Phase 1
- `contentMediaType` — media type annotation (2020-12 annotation only, not assertion), implemented as no-op validator
- `contentEncoding` — encoding annotation, implemented as no-op validator
- `contentSchema` — schema for decoded content, with base64 decoding support

### Implementation

- Three validator functions added to `JSONSchemaValidators.swift`:
  - `validateContentMediaType` — annotation no-op (passes through)
  - `validateContentEncoding` — annotation no-op (passes through)
  - `validateContentSchema` — decodes content (base64 support) and validates parsed JSON against subschema
- Wired into `validateValue` in `JSONSchema.swift` after `validateMaxLength`
- `contentSchema` supports `contentEncoding: "base64"` — base64-decodes string, parses as JSON, validates against schema
- Invalid base64 content or unparseable JSON produces validation errors with keyword `"contentSchema"`
- Non-string values skip `contentSchema` validation
- 10 tests covering: annotation pass-through, valid/invalid JSON, valid/invalid base64, non-string skip, schema validation of decoded content, absent keyword

---

## Phase 7 — Output & Error Reporting (✅ Complete)

**Branch**: `phase-7-output-error-reporting`

**Goal**: Rich error messages with schema path tracking.

### What shipped

#### Error detail
`JSONSchemaError` now includes optional `failedValue: JSON?` and `parentSchema: JSON?` properties (defaults to `nil` for backward compatibility).

#### Output modes

- **`OutputMode.basic`** (default): flat list of errors with path, keyword, message — unchanged behavior
- **`OutputMode.verbose`**: hierarchical error trees via `VerboseResult` and `VerboseError` structs

#### New types

| Type | Purpose |
|------|---------|
| `OutputMode` | Enum on `JSONSchema` with `.basic` / `.verbose` cases |
| `VerboseError` | Hierarchical error with `error: JSONSchemaError` + `children: [VerboseError]` |
| `VerboseResult` | Result wrapper with both flat `errors` and `verboseErrors` trees |

#### New API

- `JSONSchema(outputMode:)` — init parameter, defaults to `.basic`
- `schema.verboseValidation(of:)` — returns `VerboseResult` with hierarchical errors
- `buildVerboseErrors(from:)` — groups flat errors by first schema-path segment

#### Tests

12 new tests covering:
- OutputMode default and verbose setting
- Error `failedValue`/`parentSchema` (nil default, set values, Hashable)
- VerboseResult flat/hierarchical errors, throwIfInvalid
- VerboseError description with/without children
- buildVerboseErrors grouping behavior

### Files changed

| File | Change |
|------|--------|
| `JSONSchemaError.swift` | Added `failedValue` and `parentSchema` (optional, default nil) |
| `JSONSchemaOutput.swift` | New file: `VerboseError`, `VerboseResult`, `OutputMode` |
| `JSONSchema.swift` | Added `OutputMode` enum, `outputMode` property, `validation(of:)` returns `VerboseResult`, `buildVerboseErrors` |
| `JSONSchemaCoreTests.swift` | 12 new output/verbose tests |

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

## Phase 9 — Schema Generation (✅ Complete)

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

### 7. Schema compilation
Currently the schema JSON is held as-is and walked on each `validate()` call. Pattern regexes are pre-compiled at init time. Full compiled keyword tree optimization is deferred to Phase 4/10.

### 8. Output format
Phase 1 used a flat error list (`JSONSchemaResult.errors`). Phase 7 implemented `VerboseResult` with hierarchical errors via `outputMode`. The `buildVerboseErrors` grouping is a heuristic (groups by first schema-path segment) rather than true keyword-context tracking. A proper implementation would thread keyword context through all 34 validators — deferred to a future optimization phase.

### 9. `buildVerboseErrors` heuristic (deferred)
`buildVerboseErrors` groups flat errors by their first schema-path segment rather than tracking keyword context during validation. This works well for composition keywords (`allOf`/`anyOf`/`oneOf`) but may produce flat groups for deeply nested schemas. Fix: thread keyword context through all validators and build the hierarchy at error collection time. Deferred to Phase 10 (Performance Optimization).

### 10. Unicode scalar fix (2026-05-26)

**Bug**: `〮` (U+302E) is a combining character. In Swift, `"〮"` forms a single grapheme cluster,
so `ctx.string[ctx.pos] == "\""` was false even when the first Unicode scalar WAS `"`.
This caused "Unexpected token" parse errors for any JSON containing combining characters
immediately after structural characters (quotes, colons, braces, etc.).

**Fix**: Changed `ParseCursor` to advance by Unicode scalars (not grapheme clusters)
using `String.UnicodeScalarIndex` instead of `String.Index`. All character comparisons
now use `currentScalar?.value` against raw ASCII hex values.

**Files changed**:
- `ParseCursor.swift` — cursor uses `unicodeScalars.startIndex`/`endIndex`, `advance()`
  advances by one Unicode scalar, `current` returns `UnicodeScalar?`, `skipWhitespace`
  checks `value` against 0x20/0x0A/0x0D/0x09
- `JSONParser.swift` — all `ctx.string[ctx.pos] == X` → `ctx.currentScalar?.value == X`
- `JSONSAX.swift` — same fix applied to SAX parser context and all character access

**Result**: format.json parse error resolved. Draft 2020-12 goes from 1016/1162 → 1149/1295 passed
(more tests processed). All reproduction tests pass.

### 11. Schema validation fixes (2026-05-26)

**Fixes applied**:
- `validateItems`: skip items already covered by `prefixItems` (Draft 2020-12).
  Fixes `items: false` rejecting items validated by `prefixItems`.
- `typeNameOf`: float with zero fractional part (e.g. 1.0) counts as integer.
  Fixes `[type] a float with zero fractional part is an integer`.
- `schemaEqual`: compare strings at Unicode scalar level, not canonical equivalence.
  Fixes `[const] character looks the same but uses combining marks`.
- `validateMultipleOf`: use division-based check instead of remainder.
  Fixes float precision issues with tiny divisors.
- `validateAdditionalItems`: only apply when `items` is an array (tuple mode).
  Fixes Draft 7 `additionalItems: false` rejecting all items.
- `validateExclusiveMinimum`/`validateExclusiveMaximum`: numeric bounds work
  even in Draft 7 mode (fall back to Draft 2020-12 semantics).
- `validateDependencies`: added Draft 7 `dependencies` keyword support.

**Result**:
- Draft 2020-12: 1149/1295 passed (89.9%) — 131 failures remain
- Draft 7: 900/927 passed (97.1%) — 27 failures remain

---

## Phase 11 — Draft-Specific Validation Dispatch (✅ Complete, extension of Phase 8)

**Goal**: Eliminate `if draft == .draft7` conditionals from individual validator
functions by dispatching draft-specific keywords in `validateValue`.

### Current problem

Every validator that differs between drafts has `if draft == .draft7` inside its
body. This creates:
- 5+ functions with draft branching logic
- Cognitive load when reading any single validator
- Hard to add new drafts (each new draft means modifying every branching point)
- Impossible to see at a glance which keywords belong to which draft

### Proposed architecture

**Shared validators** (no draft checks, called for both drafts):
- `type`, `properties`, `required`, `minimum`/`maximum`, `multipleOf`
- `pattern`, `format`, `enum`, `const`
- `minLength`/`maxLength`, `minItems`/`maxItems`, `uniqueItems`
- `minProperties`/`maxProperties`, `propertyNames`, `patternProperties`
- `allOf`/`anyOf`/`oneOf`/`not`, `if`/`then`/`else`
- `additionalProperties` (same semantics in both drafts)
- `contains` (shared, `minContains`/`maxContains` are Draft 2020-12 only)

**Draft 7 dispatch** (only called when `draft == .draft7`):
- `validateDependencies` — combined schema + property deps
- `validateAdditionalItems` — tuple mode only
- `validateExclusiveMinimumBool` / `validateExclusiveMaximumBool`

**Draft 2020-12 dispatch** (only called when `draft == .draft202012`):
- `validateDependentSchemas` + `validateDependentRequired`
- `validatePrefixItems` + `validateItemsSchema` (skips prefixItems)
- `validateUnevaluatedItems` + `validateUnevaluatedProperties`
- `validateExclusiveMinimumNumeric` / `validateExclusiveMaximumNumeric`
- `validateContentMediaType` / `validateContentEncoding` / `validateContentSchema`
- `validateMinContains` / `validateMaxContains`

### Implementation steps

1. Split `validateExclusiveMinimum` into `*Bool` / `*Numeric` variants — no draft check
2. Split `validateItems` into shared + `validateItemsSchema` — no draft check
3. Move `validateDependencies` into Draft 7 dispatch only
4. Move `validateAdditionalItems` into Draft 7 dispatch only
5. Move Draft 2020-12 keywords into their own dispatch
6. Refactor `validateValue` in `JSONSchema.swift` to use two dispatch blocks

### Benefit

- Zero `if draft == .draft7` in validator bodies after refactor
- Adding a new draft (e.g. Draft 2019-09) just means writing a dispatch list
- Clear ownership: each draft's keyword set is explicit

### Result

After refactoring and additional fixes:
- Draft 2020-12: **1295/1295 passed (100%)** — 0 failures
- Draft 7: 911/927 passed (98.3%) — 16 failures (pre-existing)

Key fixes applied:
- validateItemsSchema: handle boolean items (true/false)
- validateContains: respect minContains=0
- validateMultipleOf: detect overflow
- evaluatedPropertyKeys: remove dependentSchemas keys
- evaluatedItemIndices: recursive tracking through composition + $ref/$dynamicRef
- evaluatedPropertyKeysRecursive: recursive tracking through composition + $ref/$dynamicRef/dependentSchemas
- if/then/else: only matching branch counts for evaluation
- contentSchema: annotation keyword, no validation errors
- Remote schema loading: pre-load remotes/ directory into registry
- ResolvedRef: return type for resolveRef carrying schema + resource URI
- resolveRef: relative URI resolution, remote registry fallback
- resolveDynamicRef: two-step resolution (normal $ref → dynamic replacement), outermost-first
- $id resolution: parentResourceURI tracking for correct parent-relative resolution
- $ref/$dynamicRef: don't skip sibling keywords in Draft 2020-12
- parentResourceURI: EvaluationContext tracks original parent URI separately
- $defs collection: outermost occurrence wins (no overwrite)
- resolveFragment: URI percent-decoding support, dynamicAnchors fallback
- $vocabulary support: metaschema vocabulary keyword filtering
- Metaschema pre-loading: official Draft 2020-12 metaschema + all components

All $dynamicRef, unevaluatedProperties, unevaluatedItems, ref, refRemote, defs, and vocabulary failures are now fixed!

### 11.1 Post-review cleanup (PR #41 suggestions)

**Applied suggestions from the review of PR #41**:

1. **Readability constants** – Added `UnicodeScalarHex` fileprivate structs with named constants for common hex values (e.g., `quote: 0x22`) in `ParseCursor.swift`, `JSONParser.swift`, and `JSONSAX.swift`. All character comparisons now use named constants instead of raw hex literals. Also added a comment about `String.UnicodeScalarIndex` not being O(1) for arbitrary indexing.

2. **Fragment fallback simplification** – In `JSONSchemaCompilation.swift`, replaced `compiled.resources.first(where: { _ in true })?.value` with `compiled.resources.values.first` (two occurrences). Avoids unnecessary closure iteration.

3. **Documentation** – Added inline doc comments explaining the semantic difference between `advanced(resourceURI:)` (remote ref, sets parent URI) and `advancedViaRef(resourceURI:)` (local ref, preserves original parent URI) in `JSONSchemaContext.swift`.

4. **evaluatedItemIndices caching** – Hoisted `dataCount` and `prefixCount` to the top of `evaluatedItemIndices` to avoid repeated lookups of `data.count` and `prefixItems.arrayValue?.count`. Reduces redundant dictionary access and loop overhead.
