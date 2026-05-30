# Bug Hunting Plan — OrderedJSON

## Objective

Systematically find correctness bugs, edge-case crashes, and logic errors across all modules of the OrderedJSON Swift library. Each phase produces a list of concrete bugs to fix (or confirms no bugs exist for that area). Phases are ordered by risk/difficulty so we find the most impactful bugs earliest.

## Session Status (2026-05-30)

### Completed in this session

- **Phase 10 edge case tests** recreated and committed: `JSONComparisonEdgeCaseTests.swift` (305 lines)
- **SIGBUS crash fix**: Split `JSONSchemaKeywordTests.swift` (2838→1923 lines) by extracting Phase 6 edge case suites into `JSONSchemaPhase6EdgeCaseTests.swift` (403 lines). Resolves swiftpm-testing-helper signal 10 crash on large test binaries.
- **Compilation test expectations fix**: Updated circular `$ref` detection test to match current source behavior (`keyword: "$ref"`, `message: "circular reference"`).
- **Phase 6 edge case file** recovered from lost state (was in "Lost Edge Case Test Files" list).

### Still lost (not yet recreated)

The following edge case test files remain lost and need recreation (see checklists in their phase sections):
- `JSONAccessEdgeCaseTests.swift` (Phase 9)
- `JSONCodableEdgeCaseTests.swift` (Phase 7)
- `JSONFlattenEdgeCaseTests.swift` (Phase 5)
- `JSONModifierEdgeCaseTests.swift` (Phase 8)
- `JSONParserEdgeCaseTests.swift` (Phase 1)
- `JSONPatchEdgeCaseTests.swift` (Phase 3)

---

## Phase 1 — Parser (JSONParser + SAX)

**Risk:** High. Recursive descent with manual unicode-scalar cursor — easy to miss edge cases.

### Check list

1. **Surrogate pair handling** (`parseUnicodeEscape`, both parser and SAX)
   - Low surrogate without preceding backslash → should error, not silently produce empty string
   - High surrogate followed by non-`\u` → SAX returns `""` (lenient), parser throws — verify consistency
   - Edge: high surrogate at end of input → crash vs. error

2. **Trailing comma logic** (`parseObject` / `parseArray`)
   - `allowTrailingCommas: true`: comma + `]` → stops. What about comma + whitespace + `]`? Already handled, but what about comma + `,` (double comma)?
   - `allowTrailingCommas: false`: should reject trailing comma — verify error is thrown

3. **Number parsing** (`parseNumber`)
   - Leading zero: `01` should be rejected. Parser allows digits after leading zero. Check: does `01` parse as `1`?
   - Negative zero: `-0` should parse as integer 0. Verify.
   - Bare `.` or `e` without digits → error. Verify `"e"`, `"."`, `"-.e1"` all fail.
   - Number > `Int64.max` → falls back to `Double`. Verify precision-loss behavior is documented and correct.
   - `0.0` → integer 0? No — `isFloat = true` due to `.` → `.float(0.0)`. Verify.

4. **String parsing edge cases**
   - Control characters (U+0000–U+001F) in strings: should error or be allowed? JSON spec says they must be escaped. Verify rejection.
   - Lone surrogates in string content (not escaped): should be rejected per spec.
   - `\x` (invalid escape) → error. `\8` → error. Verify.

5. **Depth limit** — verify `maxDepth` is checked before recursing into nested objects/arrays. Currently checked after advancing. Off-by-one?

6. **SAX accept mode** (`saxAcceptValue` vs `saxParseValue`)
   - `accept("true")` returns `true`. `accept("{")` returns `false`. Good.
   - But: does `accept` correctly reject invalid number like `-`? It advances for `-` then needs digits. If input is just `"-"`, it should fail.

7. **Trailing data after valid JSON**
   - `parse("null extra")` → should throw unexpected token. Verify.
   - `accept("null extra")` → should return `false`. Verify.

### Tools to use

- Run existing parser tests, then add targeted edge-case tests
- Fuzz with randomly-generated near-valid JSON strings

---

## Phase 2 — Binary Format Decoders (CBOR, MsgPack, UBJSON, BSON, BJData)

**Risk:** High. Multi-byte reads with manual bounds checks — easy to have off-by-one or missing checks.

### Check list

1. **Bounds-check consistency** — each `readUInt*` helper guards `pos + N <= data.count`. Verify every call site also checks before indexing. The previous bugfix commit `0ef9084f` was "add bounds checks in binary format multi-byte read functions" — verify those checks are complete and correct.

2. **CBOR half-precision float** (`halfToFloat`)
   - NaN/infinity handling: `exp == 31` returns `mant == 0 ? infinity : NaN`. Verify sign bit is preserved for negative infinity.
   - Denormalized values: formula `sign * mant / 16777216.0` — verify against IEEE 754 half-float spec.

3. **CBOR negative integers** — `-1 - argument` for `argument ≤ UInt64(Int64.max)`, else `-1.0 - Double(argument)`. Edge: `argument = 0` → `-1`. `argument = UInt64(Int64.max) + 1` → falls to float path. Verify `-1 - UInt64(Int64.max)` does not overflow.

4. **CBOR indefinite-length arrays/maps** — CBOR supports indefinite-length (major type 4/5 with info 31). Currently not handled? Verify decoder rejects or handles gracefully.

5. **BSON document length** — `decodeBSONDocument`: reads `docLen`, computes `endPos = pos + docLen - 5`. Verify:
   - `docLen` could be smaller than 5 → already guarded with `docLen >= 5`
   - `pos + docLen - 5` could overflow if `docLen` is near `Int.max`. Use `Int(docLen)` — safe?

6. **BSON string null terminator** — `data[pos + len - 1] == 0` check. Edge: `len == 0` → `pos + len - 1 = pos - 1` → out-of-bounds read. Guard `len > 0` is present. Good. But verify: `len == 1` with null terminator → body is empty. Works.

7. **BSON binary subtype** — reads `data[pos]` (subtype byte) after checking `pos + 1 + len <= data.count`. Verify `pos` is incremented correctly after reading subtype.

8. **UBJSON/BJData string length** — `decodeBJDataStringLen` returns `Int` from signed markers. Guard `len >= 0` for `Int8` and `Int16` markers. Verify `Int32` marker also guards `len >= 0`.

9. **UBJSON/BJData end markers** — `bjdataMarkerEndArray`/`bjdataMarkerEndObject` terminate arrays/objects. Verify:
   - Empty arrays with end markers work
   - Mismatched markers (e.g., `]` inside object) are caught
   - Missing end markers for optimized containers

10. **MsgPack negative integers** — `readInt64`: verify `-1 - (Int64(value) & 0xFF...)` logic. Edge: `value = 0` → `-1`. `value = Int64.max` → `-Int64.max - 1` = `Int64.min`. Verify no overflow.

11. **MsgPack string length** — `len` from `readUInt*` → `Int`. If `len > Int.max`, the conversion truncates. Guard: check `len <= UInt64(Int.max)` like CBOR does. Verify MsgPack has the same guard.

12. **All binary round-trips** — verify `decode(encode(x)) == x` for each format with edge values: `0`, `-0` (as float), `Int64.min`, `Int64.max`, `Double.nan`, `Double.infinity`, empty object, empty array, nested structures.

### Tools to use

- Add round-trip tests with edge values for each format
- Fuzz with random byte sequences to find crash bugs
- Review all read helpers for consistent bounds-checking pattern

---

## Phase 3 — JSON Patch (RFC 6902)

**Risk:** Medium. Recursive tree rebuilding with path parsing — easy to miss edge cases in pointer resolution.

### Check list

1. **Path parsing** (`parsePatchPath`)
   - `~0` → `~`, `~1` → `/`. Verify order: `~1` before `~0` in `replacingOccurrences`. What about `~01` → `~/`? Should first replace `~0` → `~` → `~1` → `/` — but order matters. Currently `~1` is replaced first, then `~0`. This means `~01` becomes `~/` correctly. Verify.
   - Edge: `~10` → `~0`? After `~1` → `/`: `/0`. After `~0` → `~`: `/0` stays. Correct.

2. **`-` append marker** — `resolvePointer` returns `nil` for `-`. `traverseAndSet` handles `-` at last segment by appending. Verify:
   - `-` as intermediate segment (not last) → error. Verified.
   - `-` on non-array → error. Verified.
   - `add` to array index equal to count → appends. `add` to index > count → error. Verify.

3. **`move` operation** — removes from source, adds to target. Edge: source and target overlap (same path). Removing changes the tree, then setting re-inserts. Is this correct per RFC? For `move` of `"/a"` to `"/b"`, removing `/a` then setting `/b` is correct. For overlapping paths like `move /a /a/b`, the removal changes the tree before the set — this is the correct RFC behavior (remove first, then add).

4. **`copy` operation** — resolves from source, then sets at target. Edge: source is `"/-"` (append marker). `resolvePointer` returns `nil` for `-` → error. Good.

5. **`test` operation** — uses `==` comparison. Verify NaN handling: `JSON.number(.float(Double.nan)) != JSON.number(.float(Double.nan))` → test fails. Is this intended? (Yes — NaN != NaN per IEEE 754.)

6. **Array remove shifts indices** — removing element at index `i` shifts subsequent elements down by 1. If patch has multiple removes targeting indices after a prior remove, the indices shift. Current implementation rebuilds the tree for each operation independently, so this is handled correctly.

7. **Empty path `""` or `"/"`** — `parsePatchPath` returns `[]`. `settingValue` with empty segments returns `value` (replaces root). `removingValue` with empty segments returns `.null`. Verify this matches RFC (replace entire document, or set to null).

### Tools to use

- Add tests for overlapping paths in move/copy
- Add tests for `-` append marker in various positions
- Test patch on nested arrays with index shifts

---

## Phase 4 — JSON Merge Patch (RFC 7396)

**Risk:** Low. Small, well-understood algorithm.

### Check list

1. **Null patch** — `patch.isNull` → replace target with `.null`. Verify.
2. **Non-object patch** — `patch` is not an object → replaces target entirely. Verify.
3. **Recursive merge** — object patches merge recursively. Edge: target has non-object at key, patch has object → overwrites (correct). Edge: target has object, patch has non-object at same key → overwrites. Edge: both null at a key → removed.
4. **In-place mutation** (`mergePatch(_:)`) — sets `self = mergePatch(patch)`. Verify no retain cycle issues with value types.

### Tools to use

- Add tests for edge cases: patch with mixed null/object/scalar keys
- Round-trip: apply patch, then inverse patch to restore original

---

## Phase 5 — Flatten / Unflatten (RFC 6901 JSON Pointer)

**Risk:** Medium. Key escaping, path reconstruction — easy to get wrong.

### Check list

1. **Key escaping** (`flatten`)
   - `~` → `~0`, `/` → `~1`. Order: first replace `~` with `~0`, then `/` with `~1`. If key contains `~1`, `~` → `~0` makes it `~01`, then `/` → `~1` doesn't match. Verify: `~1` in key becomes `~01` after first pass, then `/` → `~1` doesn't touch `~01`. Result: `~01`. When unflattening, `~0` → `~` then `~1` → `/`: `~01` → `~1` (first `~0` → `~`), then `~1` → `/` → `~/`. Wait — this is wrong! Let me check:

   In `flatten`: `key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")`
   - Input `~1`: first pass → `~01`, second pass → `~01` (no `/` to replace). Result: `~01`.
   - In `unflatten` (JSONSetPointerPath): `segment.replacingOccurrences(of: "~0", with: "~").replacingOccurrences(of: "~1", with: "/")`
   - Input `~01`: first pass `~0` → `~` → `~1`, second pass `~1` → `/` → `~/`. Result: `~/`.
   
   But the original key was `~1`. So `~/` != `~1` — this is a **bug**! The unflatten round-trip of key `~1` produces `~/` instead.

   Actually wait — let me re-read the unflatten code. In `JSONFlatten.swift`:
   ```swift
   parts = parts.map { unescapeJSONPointerSegment($0) }
   ```
   I need to check what `unescapeJSONPointerSegment` does. Let me look at the JSONPointer file.

   Actually the key escaping in `flatten` and `unflatten` are separate from JSONPointer. Let me check the actual unescape function used.

   But the point is: the order of escaping matters. RFC 6901 says: to escape a key, first replace `~` with `~0`, then replace `/` with `~1`. To unescape, first replace `~1` with `/`, then `~0` with `~`. If `flatten` uses `~0` then `~1`, and `unflatten` uses `~1` then `~0`, the order is CORRECT for unflatten. But if both use the same order, there's a bug.

   Let me check the actual `unescapeJSONPointerSegment` function in JSONPointer.swift.

   I need to read that file.

2. **Empty objects/arrays** → flattened to `null`. Verify round-trip: `flatten(unflatten(null))` works.

3. **Root-only value** — scalar root flattens to `{ "": value }`. Verify `unflatten` handles the `""` key.

4. **Non-primitive validation** — `unflatten` checks all values are primitive. Verify: object with non-primitive value throws `FlattenError.notPrimitive`.

### Tools to use

- Add round-trip tests for keys containing `~`, `/`, `~0`, `~1`
- Test empty objects/arrays round-trip

---

## Phase 6 — Schema Validation

**Risk:** High. Large codebase (`JSONSchemaValidators.swift` is 1870 lines), many keywords, draft-specific behaviors.

### Check list

1. **`type` keyword** — integer should match `"number"` type. Verify. Float with zero fractional part should match `"integer"` type (per JSON Schema). The `typeNameOf` function handles this — verify.
2. **`required` keyword** — object without required key should fail. Verify error message.
3. **`allOf`/`anyOf`/`oneOf`** — verify `oneOf` rejects when multiple schemas match. Verify error accumulation.
4. **`if`/`then`/`else`** — `if` schema matches → validate `then`. `if` fails → validate `else`. Verify: `if` schema passes but `then` fails → overall failure. `if` fails and `else` passes → overall passes.
5. **`$ref` resolution** — verify circular refs don't cause infinite recursion. The `CompiledSchema` and `RefCache` should handle this.
6. **`$defs`** — verify `$defs` keys are resolved correctly.
7. **Format validation** — `validateFormat` for strings. Verify: `email`, `uri`, `date-time`, etc. are validated correctly. Edge: non-string value → format validation is skipped (per spec). Verify.
8. **`pattern` keyword** — regex compilation errors → should fail gracefully, not crash.
9. **`uniqueItems`** — for arrays, checks all elements are pairwise unequal. Verify NaN handling: two NaN values are NOT unique per spec (NaN != NaN in JSON). But `==` on `JSON` uses `Hashable`, where NaN compares unequal. So `[NaN, NaN]` would pass `uniqueItems` — is this correct per JSON Schema? Actually in JSON, NaN is not valid JSON anyway, so this edge case doesn't arise from parsed JSON. But it could arise from programmatic construction. The spec says "they must all be different" — NaN values are technically different values, so it's arguably correct.
10. **`contentEncoding`/`contentMediaType`** — verify these are parsed but not validated (per spec, they're descriptive only for non-media-type documents).
11. **Boolean schemas** — `true` always passes, `false` always fails. Verify.
12. **Schema compilation** — `CompiledSchema` initialization walks the schema JSON. Verify: `$id` resolution with relative URIs, `$anchor` collection, `$defs` collection.

### Tools to use

- Run the official JSON Schema Test Suite (submodule)
- Add targeted tests for each keyword with edge inputs
- Fuzz with random schemas against random JSON instances

---

## Phase 7 — Codable (Encoder/Decoder)

**Risk:** Medium. Manual `KeyedContainer`, `UnkeyedContainer` implementations — easy to miss protocol requirements.

### Check list

1. **Key order preservation** — `OrderedJSONEncoder`/`OrderedJSONDecoder` should preserve key order. Verify: encode a dictionary with known key order, decode, check order matches.
2. **`JSONWithUnknownKeys`** — captures unknown keys during decoding. Verify: struct with `CodingKeys` subset → unknown keys appear in `.unknown` property.
3. **Strategy edge cases**:
   - `dateDecodingStrategy = .secondsSince1970` with non-number → error
   - `dataDecodingStrategy = .base64` with non-string → error
   - `decimalDecodingStrategy = .asString` with non-string → error
4. **`encodeAsString`** — encodes then dumps without indent. Verify matches `dump(indent: nil)`.
5. **Super encoder** — `super.superEncoder` for subclass encoding. Verify works correctly.
6. **`JSON` conforms to `Encodable`/`Decodable`** — verify `JSON.encode`/`JSON.decode` convenience methods work.

### Tools to use

- Add round-trip tests for various Codable types
- Test `JSONWithUnknownKeys` with partial coding keys

---

## Phase 8 — Modifiers (clear, remove, append, insert, setDefault, update, swap)

**Risk:** Low. Well-tested, but verify edge cases.

### Check list

1. **`update(mergingNested: true)`** — recursive merge. Verify: non-object at key in source → overwrites. Non-object at key in target → overwrites. Null → overwrites.
2. **`setDefault` with `@autoclosure`** — closure is evaluated even when key exists (it's `@autoclosure`, not `@autoclosure` with lazy eval). Wait, `@autoclosure` IS lazy — it wraps the expression in a closure that's only evaluated when called. But `defaultValue()` IS called in the `if dict[key] == nil` branch. So if key exists, the closure is never evaluated. Verify this is correct.
3. **`remove(at:)`** — negative indices silently ignored (per API docs). Verify: `remove(at: -1)` on non-empty array is no-op.
4. **`swap(with:)`** — verify `inout` semantics work correctly for value types.

### Tools to use

- Quick scan of existing tests — they look comprehensive

---

## Phase 9 — Accessors and Subscripts

**Risk:** Low. Well-tested, but verify edge cases.

### Check list

1. **`@dynamicMemberLookup` setter** — setting on non-object is silent no-op. Verify: `json.foo = bar` where `json` is array → no change.
2. **`subscript[key: String]` setter with `nil`** — removes key from object. Verify: removing last key produces empty object (not null).
3. **`intValue` / `doubleValue`** — verify: `JSON.number(.float(Double.nan)).intValue == nil`. `JSON.number(.float(Double.nan)).doubleValue == Double.nan` (wrapped). Verify `doubleValue` returns nil or NaN? Currently `case .number(.float(let d)): return d` — so it returns `Double.nan`. This is intentional.
4. **`requireFloat()`** — rejects NaN/infinity. `requireDouble()` accepts them. Verify consistency.

### Tools to use

- Quick scan of existing tests

---

## Phase 10 — Comparison Operators and Sequence Conformance

**Risk:** Low. Simple implementations.

### Check list

1. **`==` with NaN** — `JSON.number(.float(Double.nan)) != JSON.number(.float(Double.nan))`. Verify this is consistent (NaN != NaN per IEEE 754, but `Hashable` uses bitPattern which makes them equal in hashing — actually `JSONNumber`'s hash might use `bitPattern` for floats, making NaN hash equal but `==` unequal). Wait — `JSONNumber` is `.integer(Int64)` / `.float(Double)`. The `Hashable` conformance of `JSONNumber` would use `Double.bitPattern` for `.float`, so two NaN values have the same hash. But `==` on `JSON` uses `==` on `JSONNumber`, which for `.float` uses `==` on `Double`, where NaN != NaN. This means NaN values are NOT equal via `==` but ARE equal in hash — which breaks the `Hashable` contract (equal hashes for equal values, but unequal values can have equal hashes — this is fine. The contract is `a == b ⇒ a.hash == b.hash`, not the reverse). So this is acceptable.

2. **`Comparable` conformance** — verify ordering is consistent with type hierarchy (null < boolean < number < string < object < array).

3. **`Sequence` conformance** — iterate over object (key-value pairs) and array (elements). Verify: empty sequences iterate correctly.

### Tools to use

- Quick scan of existing tests

---

## Phase 11 — Cross-Module Integration Tests

**Risk:** Medium. Interactions between modules can reveal subtle bugs.

### Check list

1. **Parse → dump → parse round-trip** — parse JSON, dump it, parse again. Verify identity for various inputs (including strings with escaped chars, nested structures, edge numbers).
2. **Binary encode → parse** — encode to CBOR/MsgPack, decode, then dump as JSON. Verify output is valid JSON.
3. **Schema validate → flatten** — validate a JSON instance against a schema, then flatten the result. Verify no crashes.
4. **Patch → re-parse** — apply a patch, dump result, re-parse. Verify round-trip.
5. **Codable → JSON → patch** — encode a Codable type to JSON, apply a patch, decode back. Verify type safety.

### Tools to use

- Write integration tests that chain multiple modules

---

## Phase 12 — Fuzz Testing

**Risk:** High reward. Random inputs find crashes that manual review misses.

### Approach

1. **Parser fuzzing** — generate random strings (valid JSON prefixes + random suffixes) and verify `parse` either succeeds or throws a documented error (never crashes).
2. **Binary format fuzzing** — generate random `Data` sequences and feed to each decoder. Verify no crashes, only documented errors.
3. **Patch fuzzing** — generate random patch operations and apply to random JSON values. Verify no crashes.
4. **Schema fuzzing** — generate random schemas and validate random JSON instances. Verify no crashes.

### Success criteria

- No crashes (EXC_BAD_ACCESS, force-unwrap, index-out-of-bounds) on any input
- All errors are instances of documented error types (JSONParseError, JSONError, FlattenError, JSONPointerError, etc.)

---

## Phase 13 — Memory / Performance Edge Cases

**Risk:** Low for correctness, but important for robustness.

### Check list

1. **Deeply nested JSON** — verify `maxDepth` prevents stack overflow during recursive descent.
2. **Large strings** — verify string parsing handles very long strings (>1MB) without quadratic memory.
3. **Large arrays/objects** — verify parsing large arrays/objects doesn't cause excessive memory.
4. **Cyclic `$ref` in schemas** — verify schema compilation doesn't infinite-loop on cyclic `$ref` schemas.

---

## Execution Order

```
Phase 1  (Parser)          → highest risk, most user-facing
Phase 2  (Binary)          → highest risk, security-critical
Phase 3  (Patch)           → medium risk, complex path logic
Phase 6  (Schema)          → high risk, large code surface
Phase 7  (Codable)         → medium risk
Phase 5  (Flatten)         → medium risk, key escaping
Phase 4  (Merge Patch)     → low risk
Phase 8  (Modifiers)       → low risk
Phase 9  (Accessors)       → low risk
Phase 10 (Comparison)      → low risk
Phase 11 (Integration)     → medium risk
Phase 12 (Fuzz)            → high reward
Phase 13 (Memory/Perf)     → low risk
```

Each phase: write targeted test cases, run them, record any failures, fix the bug, verify fix.

**IMPORTANT: Commit all changes from each phase before moving to the next phase.** Uncommitted changes across multiple phases are at risk of being lost (e.g., by `git clean` or working tree resets). Each phase should produce a self-contained commit with its source changes and test files.

---

## Lost Edge Case Test Files

The following edge case test files were created during the bug hunt but **lost** before they could be committed (deleted by `git clean -fd`, not in stash because they were untracked new files). They need to be recreated from the checklists above:

| File | Phase | Checklist Items |
|------|-------|-----------------|
| `Tests/OrderedJSONTests/Access/JSONAccessEdgeCaseTests.swift` | 9 (Accessors) | dynamicMember setter, subscript nil removal, intValue/doubleValue NaN, requireFloat/requireDouble |
| `Tests/OrderedJSONTests/Codable/JSONCodableEdgeCaseTests.swift` | 7 (Codable) | Key order preservation, JSONWithUnknownKeys, strategy edge cases, encodeAsString, super encoder |
| `Tests/OrderedJSONTests/Flatten/JSONFlattenEdgeCaseTests.swift` | 5 (Flatten) | Key escaping (`~`, `/`, `~0`, `~1` round-trip), empty objects/arrays, root-only value, non-primitive validation |
| `Tests/OrderedJSONTests/Modifiers/JSONModifierEdgeCaseTests.swift` | 8 (Modifiers) | update(mergingNested:), setDefault autoclosure, remove negative index, swap inout semantics |
| `Tests/OrderedJSONTests/Parsing/JSONParserEdgeCaseTests.swift` | 1 (Parser) | Surrogate pairs, trailing commas, number edge cases, string edge cases, depth limit, SAX accept mode, trailing data |
| `Tests/OrderedJSONTests/Patch/JSONPatchEdgeCaseTests.swift` | 3 (Patch) | Path parsing (`~0`/`~1` order), `-` append marker, move/copy overlap, test with NaN, array remove index shifts, empty path |

Each file above was a `@Suite` struct with `@Test` methods covering the edge cases listed in its phase's checklist section. Recreate by following the checklist items in the corresponding phase section above.
