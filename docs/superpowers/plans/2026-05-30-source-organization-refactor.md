# Source Organization Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor OrderedJSON source and test files to follow Swift conventions — one responsibility per file, `Type+Extension.swift` naming, files split at ~400 lines (source) / ~600 lines (tests). Strip Phase N references.

**Architecture:** Pure reorganization — no behavioral changes. Each phase produces compilable, passing-tests state. Source splits first, then test splits, then comment cleanup.

**Tech Stack:** Swift 6.3, Swift Testing, no external dependencies beyond swift-collections.

**Key correction from spec:** `JSONSchemaValidators.swift` contains `extension JSONSchema { }` (validators), NOT the struct. The struct is in `JSONSchema.swift`. So `JSONSchemaValidators.swift` gets split into per-keyword extension files; `JSONSchema.swift` gets split into struct + internal method files.

---
## File Structure

### Current → Target Source Layout

```
Sources/OrderedJSON/
├── Access/
│   ├── JSONAccess.swift         → JSON+Access.swift
│   ├── JSONLookup.swift         → JSON+Lookup.swift
│   └── JSONSubscript.swift      → JSON+Subscript.swift
├── Binary/                      (keep as-is — each ~1 format, fine)
├── Builder/
│   └── JSONBuilder.swift        → JSON+ObjectBuilder.swift + JSON+ArrayBuilder.swift
├── Codable/
│   ├── OrderedJSONDecoder.swift  → split: main + 3 private containers
│   ├── OrderedJSONEncoder.swift  → split: main + 1 private container
│   ├── JSONWithUnknownKeys.swift → split: Decodable + Encodable
│   └── (JSON+Decode/Encode/Codable/CodingKey stay)
├── Core/
│   ├── JSON.swift               → stays (rename not needed)
│   ├── JSONAccessors.swift      → JSON+Accessors.swift
│   └── (JSONError, JSONNumber stay)
├── Flatten/                     → rename: JSON+Flatten.swift, JSON+Pointer.swift
├── Modifiers/
│   └── JSONClear.swift          → JSON+Modifiers.swift
├── Operators/
│   ├── JSONComparison.swift     → JSON+Comparison.swift
│   └── JSONSequence.swift       → JSON+Sequence.swift
├── Parsing/                     → rename JSONParser.swift, keep others
├── Patch/                       → rename: JSON+Patch.swift, JSON+MergePatch.swift
├── SAX/
│   └── JSONSAX.swift            → split: protocol + implementations
└── Schema/
    ├── JSONSchema.swift          → split: struct + internal method groups
    ├── JSONSchemaValidators.swift → split: per-keyword extension files
    └── JSONSchemaCompilation.swift → split: 3 files
```

---

### Task 1: Schema struct split — JSONSchema.swift

**Correction from spec:** `JSONSchema.swift` (1004 lines) contains the `JSONSchema` struct AND its internal methods (draft detection, vocabulary mapping, validation API, core validation, keyword dispatch, equality, hashable). It does NOT contain extension validators — those are in `JSONSchemaValidators.swift`.

**Files:**
- Split: `Sources/OrderedJSON/Schema/JSONSchema.swift` (1004 lines)
- Create: `Sources/OrderedJSON/Schema/JSONSchema.swift` — struct definition + init (~200 lines)
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Draft.swift` — draft detection, vocabulary keyword mapping
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Validation.swift` — validation API, verbose output, core validation, keyword dispatch
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Equality.swift` — schema-aware equality, Hashable conformance

- [ ] **Step 1: Read full JSONSchema.swift into context**

- [ ] **Step 2: Create JSONSchema.swift (struct only)**
  Extract lines 1-175 (imports + struct definition + init + stored properties). Keep the full DOCC comments. Strip any "Phase N" references.

- [ ] **Step 3: Create JSONSchema+Draft.swift**
  Extract draft detection (`detectDraft`) and vocabulary keyword mapping methods. Preserve DOCC.

- [ ] **Step 4: Create JSONSchema+Validation.swift**
  Extract `validate()`, `validating()`, `isValid()`, `validateValue()`, `evaluateWithTracking()`, keyword dispatch, output/verbose methods. Preserve DOCC.

- [ ] **Step 5: Create JSONSchema+Equality.swift**
  Extract schema-aware equality and Hashable conformance. Preserve DOCC.

- [ ] **Step 6: Build and verify**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON
swift build 2>&1
```

Expected: Build succeeds. If there are missing symbols from the split, check what references the old locations.

- [ ] **Step 7: Commit**

```bash
git add Sources/OrderedJSON/Schema/
git commit -m "refactor(schema): split JSONSchema.swift into struct + extension files"
```

---

### Task 2: Schema validators split — JSONSchemaValidators.swift → per-keyword

**Files:**
- Split: `Sources/OrderedJSON/Schema/JSONSchemaValidators.swift` (1869 lines)
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Shared.swift` — shared validators called for both drafts
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Type.swift` — type keyword validation
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Properties.swift` — properties, required
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Numeric.swift` — minimum, maximum, exclusiveMinimum, exclusiveMaximum, multipleOf
- Create: `Sources/OrderedJSON/Schema/JSONSchema+String.swift` — minLength, maxLength, pattern, enum, const
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Composition.swift` — allOf, anyOf, oneOf, not, if/then/else
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Array.swift` — items, prefixItems, minItems/maxItems, uniqueItems, contains, unevaluatedItems, additionalItems
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Object.swift` — minProperties/maxProperties, propertyNames, patternProperties, additionalProperties, dependentSchemas, dependentRequired, unevaluatedProperties
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Draft7.swift` — Draft 7 specific validators (exclusiveMin/Max boolean, format, dependencies, additionalItems, items tuple)
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Draft202012.swift` — Draft 2020-12 specific validators (dependentSchemas, dependentRequired, prefixItems, items schema, evaluation tracking)
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Unevaluated.swift` — unevaluatedItems, unevaluatedProperties, contentMediaType, contentEncoding, contentSchema, minContains/maxContains

- [ ] **Step 1: Read full JSONSchemaValidators.swift**

- [ ] **Step 2: Create each per-keyword file**
  For each MARK section in the source, extract the corresponding methods into its own file. Each file contains `extension JSONSchema { ... }` with the relevant methods. Preserve all DOCC comments. Strip "Phase N" references from comments.

  Key MARK sections and their targets:
  ```
  // MARK: - Shared validators            → JSONSchema+Shared.swift
  // MARK: - Keyword: type               → JSONSchema+Type.swift
  // MARK: - Keyword: properties         → JSONSchema+Properties.swift (combine with required)
  // MARK: - Keyword: required
  // MARK: - Keyword: minimum            → JSONSchema+Numeric.swift
  // MARK: - Keyword: maximum
  // MARK: - Keyword: exclusiveMinimum
  // MARK: - Keyword: exclusiveMaximum
  // MARK: - Keyword: multipleOf
  // MARK: - Keyword: pattern            → JSONSchema+String.swift
  // MARK: - Keyword: enum
  // MARK: - Keyword: const
  // MARK: - Keyword: minLength
  // MARK: - Keyword: maxLength
  // MARK: - Composition: allOf          → JSONSchema+Composition.swift
  // MARK: - Composition: anyOf
  // MARK: - Composition: oneOf
  // MARK: - Composition: not
  // MARK: - Composition: if/then/else
  // MARK: - Array keywords (shared)     → JSONSchema+Array.swift
  // MARK: - Object keywords (shared)    → JSONSchema+Object.swift
  // MARK: - Draft 7 specific            → JSONSchema+Draft7.swift
  // MARK: - Draft 2020-12 specific      → JSONSchema+Draft202012.swift
  // MARK: - Evaluation tracking         → JSONSchema+Unevaluated.swift (merge with unevaluatedItems/Properties)
  ```

- [ ] **Step 3: Delete JSONSchemaValidators.swift**

- [ ] **Step 4: Build and verify**

```bash
swift build 2>&1
```

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/OrderedJSON/Schema/
git commit -m "refactor(schema): split JSONSchemaValidators.swift into per-keyword extension files"
```

---

### Task 3: Schema compilation split — JSONSchemaCompilation.swift

**Files:**
- Split: `Sources/OrderedJSON/Schema/JSONSchemaCompilation.swift` (825 lines)
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Compilation.swift` — CompiledSchema struct, keyword cache
- Create: `Sources/OrderedJSON/Schema/JSONSchema+URI.swift` — RFC 3986 URI joining
- Create: `Sources/OrderedJSON/Schema/JSONSchema+Ref.swift` — ResolvedRef, ResourceScope, fragment resolution

- [ ] **Step 1: Read JSONSchemaCompilation.swift**

- [ ] **Step 2: Create JSONSchema+Compilation.swift**
  Extract `CompiledSchema` struct and keyword cache logic. Note: this file currently has free-standing structs (`ResolvedRef`, `ResourceScope`, `CompiledSchema`), not extensions. Keep them as free-standing types.

- [ ] **Step 3: Create JSONSchema+URI.swift**
  Extract RFC 3986 URI joining methods.

- [ ] **Step 4: Create JSONSchema+Ref.swift**
  Extract `ResolvedRef`, `ResourceScope`, and fragment resolution methods.

- [ ] **Step 5: Delete JSONSchemaCompilation.swift**

- [ ] **Step 6: Build and verify**

```bash
swift build 2>&1
```

- [ ] **Step 7: Commit**

```bash
git add Sources/OrderedJSON/Schema/
git commit -m "refactor(schema): split JSONSchemaCompilation.swift into 3 files"
```

---

### Task 4: Codable splits — Decoder, Encoder, JSONWithUnknownKeys

**Files:**
- Split: `Sources/OrderedJSON/Codable/OrderedJSONDecoder.swift` (917 lines)
- Split: `Sources/OrderedJSON/Codable/OrderedJSONEncoder.swift` (916 lines)
- Split: `Sources/OrderedJSON/Codable/JSONWithUnknownKeys.swift` (571 lines)

- [ ] **Step 1: Read OrderedJSONDecoder.swift**

- [ ] **Step 2: Create OrderedJSONDecoder.swift (main)**
  Keep public struct + DateDecodingStrategy, DataDecodingStrategy, DecimalDecodingStrategy enums. Remove private container types.

- [ ] **Step 3: Create OrderedJSONDecoder+KeyedContainer.swift**
  Extract `_JSONKeyedDecodingContainer` struct. Keep as `package` (internal) access.

- [ ] **Step 4: Create OrderedJSONDecoder+UnkeyedContainer.swift**
  Extract `_JSONUnkeyedDecodingContainer` struct.

- [ ] **Step 5: Create OrderedJSONDecoder+SingleValue.swift**
  Extract `_JSONSingleValueDecodingContainer` struct.

- [ ] **Step 6: Read OrderedJSONEncoder.swift**

- [ ] **Step 7: Create OrderedJSONEncoder.swift (main)**
  Keep public struct + DateEncodingStrategy, DataEncodingStrategy, DecimalEncodingStrategy enums.

- [ ] **Step 8: Create OrderedJSONEncoder+SingleValue.swift**
  Extract `_JSONSingleValueEncodingContainer` struct.

- [ ] **Step 9: Read JSONWithUnknownKeys.swift**

- [ ] **Step 10: Create JSONWithUnknownKeys+Decodable.swift**
  Extract `init(from:)` Decodable conformance.

  Note: `JSONWithUnknownKeys` struct is in the main file. The Decodable `init` is extracted. The Encodable `encode` stays in the main file since it's small.

- [ ] **Step 11: Build and verify**

```bash
swift build 2>&1
```

- [ ] **Step 12: Commit**

```bash
git add Sources/OrderedJSON/Codable/
git commit -m "refactor(codable): split decoder, encoder, JSONWithUnknownKeys into separate files"
```

---

### Task 5: Other source splits — Builder, SAX, Parser, Modifiers

**Files:**
- Split: `Sources/OrderedJSON/Builder/JSONBuilder.swift` (618 lines) → 2 files
- Split: `Sources/OrderedJSON/SAX/JSONSAX.swift` (679 lines) → 2 files
- Split: `Sources/OrderedJSON/Parsing/JSONParser.swift` (619 lines) → extract Character extension
- Rename: `Sources/OrderedJSON/Modifiers/JSONClear.swift` → `JSON+Modifiers.swift`

- [ ] **Step 1: Read JSONBuilder.swift**

- [ ] **Step 2: Create JSON+ObjectBuilder.swift**
  Extract `JSON.ObjectBuilder` type. Preserve DOCC.

- [ ] **Step 3: Create JSON+ArrayBuilder.swift**
  Extract `JSON.ArrayBuilder` type. Preserve DOCC.

- [ ] **Step 4: Delete JSONBuilder.swift**

- [ ] **Step 5: Read JSONSAX.swift**

- [ ] **Step 6: Create JSONSAXEventHandler.swift**
  Extract `JSONSAXEventHandler` protocol definition. Preserve DOCC.

- [ ] **Step 7: Update JSONSAX.swift**
  Keep only the extension implementations on JSON. Preserve DOCC.

- [ ] **Step 8: Read JSONParser.swift**

- [ ] **Step 9: Create UnicodeScalarHex.swift (consolidate)**
  Extract `Character` extension from JSONParser.swift. Note: `UnicodeScalarHex.swift` already exists with hex parsing — merge the Character extension there.

- [ ] **Step 10: Rename JSONClear.swift → JSON+Modifiers.swift**
  No content change, just rename. The file contains clear(), remove(), append(), insert(), setDefault(), update(), swap() — all modifiers.

- [ ] **Step 11: Build and verify**

```bash
swift build 2>&1
```

- [ ] **Step 12: Commit**

```bash
git add Sources/OrderedJSON/Builder/ Sources/OrderedJSON/SAX/ Sources/OrderedJSON/Parsing/ Sources/OrderedJSON/Modifiers/
git commit -m "refactor: split Builder, SAX, Parser; rename modifiers"
```

---

### Task 6: File renames — Type.swift → Type+Extension.swift pattern

Rename files that don't follow the `JSON+Extension.swift` convention. These are pure renames — no content changes.

- [ ] **Step 1: Rename Access files**
  ```
  Sources/OrderedJSON/Access/JSONAccess.swift    → JSON+Access.swift
  Sources/OrderedJSON/Access/JSONLookup.swift    → JSON+Lookup.swift
  Sources/OrderedJSON/Access/JSONSubscript.swift → JSON+Subscript.swift
  ```

- [ ] **Step 2: Rename Core files**
  ```
  Sources/OrderedJSON/Core/JSONAccessors.swift → JSON+Accessors.swift
  ```

- [ ] **Step 3: Rename Flatten files**
  ```
  Sources/OrderedJSON/Flatten/JSONFlatten.swift → JSON+Flatten.swift
  Sources/OrderedJSON/Flatten/JSONPointer.swift → JSON+Pointer.swift
  ```

- [ ] **Step 4: Rename Operators files**
  ```
  Sources/OrderedJSON/Operators/JSONComparison.swift → JSON+Comparison.swift
  Sources/OrderedJSON/Operators/JSONSequence.swift   → JSON+Sequence.swift
  ```

- [ ] **Step 5: Rename Patch files**
  ```
  Sources/OrderedJSON/Patch/JSONPatch.swift      → JSON+Patch.swift
  Sources/OrderedJSON/Patch/JSONMergePatch.swift → JSON+MergePatch.swift
  ```

- [ ] **Step 6: Update all imports across the project**
  Any file that `@testable import` or references these files by name needs updating. Run `swift build` to detect stale references.

  ```bash
  swift build 2>&1
  ```

  If build fails, grep for old filenames in error messages and update corresponding imports.

- [ ] **Step 7: Commit**

```bash
git add Sources/OrderedJSON/
git commit -m "style: rename source files to Type+Extension.swift convention"
```

---

### Task 7: Test schema splits — keyword tests, compilation, core, phase 6

**Files:**
- Split: `Tests/OrderedJSONTests/Schema/JSONSchemaKeywordTests.swift` (1923 lines, 28 structs)
- Split: `Tests/OrderedJSONTests/Schema/JSONSchemaCompilationTests.swift` (1060 lines)
- Split: `Tests/OrderedJSONTests/Schema/JSONSchemaCoreTests.swift` (599 lines)
- Split: `Tests/OrderedJSONTests/Schema/JSONSchemaPhase6EdgeCaseTests.swift` (548 lines)

- [ ] **Step 1: Read JSONSchemaKeywordTests.swift**
  This file has ~28 test structs, one per keyword. Each struct has a `@Suite` annotation and multiple `@Test` methods.

- [ ] **Step 2: Create per-keyword test files**
  Split each struct into its own file. File name = struct name. Preserve all DOCC and test code. Strip Phase N references.

  Create these files in `Tests/OrderedJSONTests/Schema/`:
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
  - `JSONSchemaFormatTests.swift` (the format tests at the bottom of the file)

- [ ] **Step 3: Read JSONSchemaCompilationTests.swift**
  Split by compilation phase into logical groups.

- [ ] **Step 4: Read JSONSchemaCoreTests.swift**
  Split by concern.

- [ ] **Step 5: Read JSONSchemaPhase6EdgeCaseTests.swift**
  Split by keyword.

- [ ] **Step 6: Delete the original monolithic test files**
  Delete `JSONSchemaKeywordTests.swift`, `JSONSchemaCompilationTests.swift`, `JSONSchemaCoreTests.swift`, `JSONSchemaPhase6EdgeCaseTests.swift`.

- [ ] **Step 7: Build and run tests**

```bash
swift test 2>&1
```

Expected: All tests pass, same count as before.

- [ ] **Step 8: Commit**

```bash
git add Tests/OrderedJSONTests/Schema/
git commit -m "refactor(tests): split schema test files per keyword and concern"
```

---

### Task 8: Test binary splits — per-format files

**Files:**
- Split: `Tests/OrderedJSONTests/Binary/JSONBinaryTests.swift` (1926 lines, 8 structs)
- Split: `Tests/OrderedJSONTests/Binary/JSONBinaryEdgeCaseTests.swift` (771 lines)

- [ ] **Step 1: Read JSONBinaryTests.swift**
  Contains structs: `JSONCBORTests`, `JSONMsgPackTests`, `JSONUBJSONTests`, `JSONBSONTests`, `JSONBJDataTests`, `JSONOverflowTests`, `JSONBinaryRoundTripEdgeTests`, `JSONEdgeCaseTests`.

- [ ] **Step 2: Create per-format test files**
  Each struct → its own file:
  - `JSONCBORTests.swift`
  - `JSONMsgPackTests.swift`
  - `JSONUBJSONTests.swift`
  - `JSONBSONTests.swift`
  - `JSONBJDataTests.swift`
  - `JSONOverflowTests.swift`
  - `JSONBinaryRoundTripEdgeTests.swift`
  - `JSONEdgeCaseTests.swift`

- [ ] **Step 3: Read JSONBinaryEdgeCaseTests.swift**
  Split its structs into corresponding per-format files (merge with existing or keep separate).

- [ ] **Step 4: Delete original monolithic files**
  Delete `JSONBinaryTests.swift`, `JSONBinaryEdgeCaseTests.swift`.

- [ ] **Step 5: Build and run tests**

```bash
swift test 2>&1
```

- [ ] **Step 6: Commit**

```bash
git add Tests/OrderedJSONTests/Binary/
git commit -m "refactor(tests): split binary test files per format"
```

---

### Task 9: Test other splits — Codable, README, Patch, Integration, Builder, Parser

**Files:**
- Split: `Tests/OrderedJSONTests/Codable/JSONCodableTests.swift` (1500 lines)
- Split: `Tests/OrderedJSONTests/Codable/JSONCodableEdgeCaseTests.swift` (897 lines)
- Split: `Tests/OrderedJSONTests/READMEExamplesTests.swift` (1095 lines)
- Split: `Tests/OrderedJSONTests/Patch/JSONPatchEdgeCaseTests.swift` (1114 lines)
- Split: `Tests/OrderedJSONTests/Patch/JSONPatchTests.swift` (623 lines)
- Split: `Tests/OrderedJSONTests/Integration/JSONIntegrationTests.swift` (932 lines)
- Split: `Tests/OrderedJSONTests/Builder/JSONBuilderTests.swift` (683 lines)
- Split: `Tests/OrderedJSONTests/Parsing/JSONParserEdgeCaseTests.swift` (657 lines)

- [ ] **Step 1: Read and split JSONCodableTests.swift**
  Split into focused test files by concern (Codable conformance, encoder tests, decoder tests).

- [ ] **Step 2: Read and split JSONCodableEdgeCaseTests.swift**
  Split by edge case category.

- [ ] **Step 3: Read and split READMEExamplesTests.swift**
  Split by example topic (quick start, creating values, parsing, accessing, etc.).

- [ ] **Step 4: Read and split JSONPatchEdgeCaseTests.swift**
  Split by edge case category (path parsing, move/copy, test NaN, etc.).

- [ ] **Step 5: Read and split JSONPatchTests.swift**
  Split by patch operation (add, remove, replace, move, copy, test).

- [ ] **Step 6: Read and split JSONIntegrationTests.swift**
  Split by integration scenario.

- [ ] **Step 7: Read and split JSONBuilderTests.swift**
  Split by builder type (ObjectBuilder, ArrayBuilder).

- [ ] **Step 8: Read and split JSONParserEdgeCaseTests.swift**
  Split by edge case category.

- [ ] **Step 9: Delete original monolithic files**

- [ ] **Step 10: Build and run tests**

```bash
swift test 2>&1
```

- [ ] **Step 11: Commit**

```bash
git add Tests/OrderedJSONTests/
git commit -m "refactor(tests): split codable, readme, patch, integration, builder, parser test files"
```

---

### Task 10: Phase N comment cleanup — strip all Phase references

**Files:** All source and test files that still contain "Phase N" references.

- [ ] **Step 1: Find all Phase N references**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON
grep -rn "Phase [0-9]\+\|phase [0-9]\+\|Phase [0-9]\+\|Phase [0-9]\+:" Sources/ Tests/ --include="*.swift"
```

- [ ] **Step 2: Strip each reference inline**
  For each file, remove lines containing "Phase N" markers (e.g., `// Phase 1:`, `// Phase 2 —`, `/// Phase 3 edge case`). Preserve surrounding DOCC and code comments.

  Use Edit tool on each file. Common patterns to remove:
  - `// MARK: - Phase N: ...`
  - `/// Phase N ...`
  - `// Phase N ...`
  - Any checklist numbering that refers to bug hunt phases

- [ ] **Step 3: Build and run tests**

```bash
swift test 2>&1
```

- [ ] **Step 4: Commit**

```bash
git add Sources/ Tests/
git commit -m "chore: strip Phase N references from comments"
```

---

### Task 11: Final build and test

- [ ] **Step 1: Full build**

```bash
swift build 2>&1
```

Expected: Build succeeds with no warnings about unused files.

- [ ] **Step 2: Full test suite**

```bash
swift test 2>&1
```

Expected: All tests pass. Compare test count to baseline (should be identical).

- [ ] **Step 3: Verify CLAUDE.md is still accurate**
  Check if any file paths referenced in CLAUDE.md need updating. Update if needed.

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "chore: final build verification after source organization refactor"
```
