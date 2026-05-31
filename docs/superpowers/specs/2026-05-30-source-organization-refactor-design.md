# Source Organization Refactor Design

## Goal

Refactor OrderedJSON source and test files to follow Swift API Design Guidelines for naming, organization, and clarity. Split oversized files (>400 lines source, >600 lines tests) into focused files with one clear responsibility. Clean up misleading file names and Phase N references.

## Guiding Principles

1. **One responsibility per file** — a file should contain one type or one extension on one type
2. **Naming matches content** — `JSONSchema.swift` contains the `JSONSchema` struct, `JSONSchema+Validators.swift` contains validators
3. **Swift convention** — extensions use `Type+ExtensionName.swift` pattern
4. **Preserve all DOCC comments** — keep every documentation comment during splits
5. **Strip Phase N references** — remove all "Phase 1"-"Phase 13" and "phase N" markers from comments
6. **Test files mirror source** — one test file per source file where practical

## Source File Changes

### Schema/ directory (rename + split)

**Rename** `JSONSchemaValidators.swift` → `JSONSchema.swift` (the struct)

**Split** `JSONSchema.swift` (was extensions file, 1004 lines) into per-keyword files:
- `JSONSchema+Type.swift` — type validation
- `JSONSchema+Properties.swift` — properties, required, patternProperties, additionalProperties
- `JSONSchema+Numeric.swift` — minimum, maximum, exclusiveMinimum, exclusiveMaximum, multipleOf
- `JSONSchema+String.swift` — minLength, maxLength, pattern, enum, const
- `JSONSchema+Composition.swift` — allOf, anyOf, oneOf, not, if/then/else
- `JSONSchema+Array.swift` — items, prefixItems, minItems, maxItems, uniqueItems, contains, unevaluatedItems
- `JSONSchema+Object.swift` — minProperties, maxProperties, propertyNames, dependentSchemas, dependentRequired, unevaluatedProperties
- `JSONSchema+Format.swift` — format validation (merge with existing JSONSchemaFormat.swift)
- `JSONSchema+Shared.swift` — shared validators, draft detection, vocabulary keyword mapping, evaluation tracking helpers

**Split** `JSONSchemaCompilation.swift` (825 lines):
- `JSONSchemaCompilation.swift` — CompiledSchema struct, core compilation logic
- `JSONSchemaCompilation+URI.swift` — RFC 3986 URI joining
- `JSONSchemaCompilation+Ref.swift` — ResolvedRef, ResourceScope, fragment resolution

Keep as-is: `JSONSchemaContext.swift`, `JSONSchemaError.swift`, `JSONSchemaFormat.swift`, `JSONSchemaFormatOptions.swift`, `JSONSchemaGeneration.swift`, `JSONSchemaOutput.swift`, `JSONSchemaPatterns.swift`, `JSONSchemaRefCache.swift`, `JSONSchemaRegex.swift`, `JSONSchemaResult.swift`

### Codable/ directory (split)

`OrderedJSONDecoder.swift` (917 lines):
- Keep public struct + enum strategies
- Extract `_JSONKeyedDecodingContainer` → `OrderedJSONDecoder+KeyedContainer.swift`
- Extract `_JSONUnkeyedDecodingContainer` → `OrderedJSONDecoder+UnkeyedContainer.swift`
- Extract `_JSONSingleValueDecodingContainer` → `OrderedJSONDecoder+SingleValue.swift`

`OrderedJSONEncoder.swift` (916 lines):
- Keep public struct + enum strategies
- Extract `_JSONSingleValueEncodingContainer` → `OrderedJSONEncoder+SingleValue.swift`

`JSONWithUnknownKeys.swift` (571 lines):
- Split Decodable conformance → `JSONWithUnknownKeys+Decodable.swift`
- Keep Encodable conformance in main file (or split both ways)

### Other source splits

`JSONBuilder.swift` (618 lines) → split into:
- `JSON+ObjectBuilder.swift` — JSON.ObjectBuilder
- `JSON+ArrayBuilder.swift` — JSON.ArrayBuilder

`JSONSAX.swift` (679 lines) → split into:
- `JSONSAXEventHandler.swift` — protocol definition
- `JSONSAX.swift` — extension implementations

`JSONParser.swift` (619 lines) → extract Character extension into `UnicodeScalarHex.swift` (already exists, consolidate)

`JSONClear.swift` (162 lines) → rename to `JSONModifiers.swift` (contains all modifier methods)

### Renamed files (content unchanged)

- `Core/JSONAccessors.swift` → `Core/JSON+Accessors.swift` (Swift convention)
- `Access/JSONAccess.swift` → `Access/JSON+Access.swift`
- `Access/JSONLookup.swift` → `Access/JSON+Lookup.swift`
- `Access/JSONSubscript.swift` → `Access/JSON+Subscript.swift`
- `Modifiers/JSONClear.swift` → `Modifiers/JSON+Modifiers.swift`
- `Operators/JSONComparison.swift` → `Operators/JSON+Comparison.swift`
- `Operators/JSONSequence.swift` → `Operators/JSON+Sequence.swift`
- `Flatten/JSONFlatten.swift` → `Flatten/JSON+Flatten.swift`
- `Flatten/JSONPointer.swift` → `Flatten/JSON+Pointer.swift`
- `Patch/JSONPatch.swift` → `Patch/JSON+Patch.swift`
- `Patch/JSONMergePatch.swift` → `Patch/JSON+MergePatch.swift`

## Test File Changes

### Schema/ test splits

`JSONSchemaKeywordTests.swift` (1923 lines, 28 test structs) → split per keyword, one file per struct:
- `JSONSchemaTypeValidationTests.swift`
- `JSONSchemaPropertiesTests.swift`
- `JSONSchemaRequiredTests.swift`
- `JSONSchemaNumericBoundsTests.swift`
- `JSONSchemaExclusiveBoundsTests.swift`
- `JSONSchemaMultipleOfTests.swift`
- `JSONSchemaPatternTests.swift`
- `JSONSchemaEnumTests.swift`
- `JSONSchemaConstTests.swift`
- `JSONSchemaAllOfTests.swift`
- `JSONSchemaAnyOfTests.swift`
- `JSONSchemaOneOfTests.swift`
- `JSONSchemaNotTests.swift`
- `JSONSchemaIfThenElseTests.swift`
- `JSONSchemaDependentSchemasTests.swift`
- `JSONSchemaDependentRequiredTests.swift`
- `JSONSchemaItemsTests.swift`
- `JSONSchemaPrefixItemsTests.swift`
- `JSONSchemaMinMaxItemsTests.swift`
- `JSONSchemaUniqueItemsTests.swift`
- `JSONSchemaContainsTests.swift`
- `JSONSchemaMinMaxPropertiesTests.swift`
- `JSONSchemaPropertyNamesTests.swift`
- `JSONSchemaPatternPropertiesTests.swift`
- `JSONSchemaAdditionalPropertiesTests.swift`
- `JSONSchemaUnevaluatedPropertiesTests.swift`
- `JSONSchemaAdditionalItemsTests.swift`
- `JSONSchemaUnevaluatedItemsTests.swift`
- `JSONSchemaFormatTests.swift`

`JSONSchemaCompilationTests.swift` (1060 lines) → split by compilation phase
`JSONSchemaCoreTests.swift` (599 lines) → split by concern
`JSONSchemaPhase6EdgeCaseTests.swift` (548 lines) → split by keyword

### Binary/ test splits

`JSONBinaryTests.swift` (1926 lines, 8 test structs) → split per format:
- `JSONCBORTests.swift`
- `JSONMsgPackTests.swift`
- `JSONUBJSONTests.swift`
- `JSONBSONTests.swift`
- `JSONBJDataTests.swift`
- `JSONOverflowTests.swift`
- `JSONBinaryRoundTripEdgeTests.swift`
- `JSONEdgeCaseTests.swift`

`JSONBinaryEdgeCaseTests.swift` (771 lines) → split per format

### Other test splits

`JSONCodableTests.swift` (1500 lines) → split by concern
`JSONCodableEdgeCaseTests.swift` (897 lines) → split by edge case
`READMEExamplesTests.swift` (1095 lines) → split by example topic
`JSONPatchEdgeCaseTests.swift` (1114 lines) → split by edge case category
`JSONIntegrationTests.swift` (932 lines) → split by integration scenario
`JSONBuilderTests.swift` (683 lines) → split by builder type
`JSONParserEdgeCaseTests.swift` (657 lines) → split by edge case
`JSONPatchTests.swift` (623 lines) → split by operation

## Implementation Order

The work is split into phases to keep each commit focused and testable:

1. **Schema struct rename** — rename `JSONSchemaValidators.swift` → `JSONSchema.swift`, fix all imports
2. **Schema extension splits** — split `JSONSchema.swift` into per-keyword files
3. **Schema compilation splits** — split `JSONSchemaCompilation.swift` into 3 files
4. **Codable splits** — split decoder, encoder, JSONWithUnknownKeys
5. **Other source splits** — Builder, SAX, Parser, Modifiers rename
6. **File renames** — all `Type.swift` → `Type+Extension.swift` renames
7. **Test schema splits** — keyword tests, compilation tests, core tests, phase 6 tests
8. **Test binary splits** — per-format test files
9. **Test other splits** — Codable, README, Patch, Integration, Builder, Parser
10. **Phase N comment cleanup** — strip all Phase N references across all files
11. **Build and test** — `swift build && swift test`

## Phase N Cleanup

During every file move/split, strip references to:
- "Phase 1" through "Phase 13"
- "phase N" (lowercase)
- "Phase N:" markers in comments
- Any checklist-style numbering ("1.", "2." etc that refers to bug hunt phases)

Preserve all DOCC comments (`///` documentation), inline code comments (`//`), and markdown documentation.

## Verification

After each phase: `swift build` must succeed, `swift test` must pass with same results as before.
