# API Design Plan — Swift API Design Guidelines Alignment

## Overview

Align the `JSON` public API surface with the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). The current API mirrors `nlohmann/json` (C++) naming conventions, which introduces non-Swifty names, overload ambiguity, inconsistent mutating pairs, and silent no-op behaviors.

## Guiding Principles

1. **Clarity at the point of use** — call sites must read as clear English
2. **Consistent mutating/nonmutating pairs** — `sort` / `sorted`, `formUnion` / `union`
3. **Boolean APIs read as assertions** — `isEmpty`, `contains`, `intersects`
4. **Remove C++-isms** — `push_back`, `emplace`, `getValue`, `nullValue()`
5. **Document O(n) properties** — `objectKeys`, `items`, `keys`, `entries`
6. **Resolve overload ambiguity** — `contains(_:)` unlabeled String vs JSON

## Phases

---

### Phase 1: Remove C++ Legacy Names (High Impact, Breaking)

| Current | Proposed | Rationale |
|---|---|---|
| `nullValue()` | Remove (`.null` property exists) | Redundant — `.null` is the idiomatic Swift API |
| `push_back(_:)` | `append(_:)` already exists | Duplicate; remove `push_back` |
| `emplace_back(_:)` | Remove | Duplicate of `append`; no Swift justification |
| `emplace_nested(key:default:)` | Keep as `emplace(key:default:)` | Useful pattern; rename to `insertIfAbsent(key:default:)` later |
| `getValue(forKey:default:)` | `value(forKey:default:)` | Remove `get` prefix — Swift conventions |
| `patchInPlace(_:)` | `mutating func patch(_:)` | Mutating overload of `patch` |
| `fromCBOR` / `toCBOR` | `init(cbor:)` / `cbor()` | Factory/conversion naming |
| (same for MsgPack, UBJSON, BSON, BJData) | `init(msgPack:)` / `msgPack()` etc | |

**Files affected:**
- `Sources/OrderedJSON/Core/JSON.swift` — remove `nullValue()`
- `Sources/OrderedJSON/Modifiers/JSONClear.swift` — remove `push_back`, `emplace`, `emplace_back`
- `Sources/OrderedJSON/Access/JSONAccess.swift` — rename `getValue` → `value`
- `Sources/OrderedJSON/Patch/JSONPatch.swift` — add mutating `patch(_:)`, deprecate `patchInPlace`
- `Sources/OrderedJSON/Binary/*` — rename `fromX`/`toX` to `init(x:)` / `x()`

---

### Phase 2: Mutating/Nonmutating Pairs (Medium Impact) ✅

| Current | Proposed | Rationale |
|---|---|---|
| `clear()` mutating | Add `cleared()` nonmutating | Consistent pair pattern | ✅ Done
| `patch(_:)` nonmutating + `patchInPlace(_:)` mutating | `patch(_:)` nonmutating + `patching(_:)` mutating | `sort`/`sorted` pattern — mutating gets -ing form | ✅ Done in Phase 1

**Files affected:**
- `Sources/OrderedJSON/Modifiers/JSONClear.swift` — add `cleared()` (done)
- `Sources/OrderedJSON/Patch/JSONPatch.swift` — renamed `patchInPlace` → `patching` (done in Phase 1)
- `Tests/OrderedJSONTests/Modifiers/JSONModifierTests.swift` — add `cleared()` tests (done)

---

### Phase 3: Argument Labels & Overload Safety (High Impact) ✅

**Completed:** All API signatures updated with explicit argument labels.

| Method | Old | New |
|-------|-----|-----|
| `contains(_: String)` | `contains(_ key: String)` | `contains(key key: String)` |
| `contains(_: JSON)` | `contains(_ element: JSON)` | `contains(element element: JSON)` |
| `value(_:default:)` (key) | `value(_ key: String, default:)` | `value(forKey key: String, default:)` |
| `value(_:default:)` (index) | `value(_ index: Int, default:)` | `value(at index: Int, default:)` |
| `at(_:)` (key) | `at(_ key: String)` | `at(key key: String)` |
| `at(_:)` (index) | `at(_ index: Int)` | `at(index index: Int)` |

**Files affected:**
- `Sources/OrderedJSON/Access/JSONLookup.swift`
- `Sources/OrderedJSON/Access/JSONSubscript.swift`
- `Tests/OrderedJSONTests/Access/JSONAccessTests.swift`

---

### Phase 4: Value Extraction Names (Medium Impact) ✅

| Current | Proposed | Rationale |
|---|---|---|
| `stringValue` → `String?` | Keep — standard Swift | ✅ OK |
| `boolValue` → `Bool?` | Keep — standard Swift | ✅ OK |
| `intValue` → `Int64?` | Keep — standard Swift | ✅ OK |
| `floatValue` → `doubleValue` | Rename to `doubleValue` | `floatValue` returns `Double?`, misleading name | ✅ Done
| `numberValue` → `JSONNumber?` | Keep — standard Swift | ✅ OK |
| `arrayValue` → `[JSON]?` | Keep — standard Swift | ✅ OK |
| `objectValue` → `OrderedDictionary`? | Keep — standard Swift | ✅ OK |

**Files affected:**
- `Sources/OrderedJSON/Core/JSON.swift` — rename `floatValue` → `doubleValue` (done)
- `Sources/OrderedJSON/Schema/JSONSchemaValidators.swift` — update call sites (done)
- `Tests/OrderedJSONTests/Core/JSONCoreTests.swift` — update test calls (done)

---

### Phase 5: Builder API Labels (Medium Impact) ✅

#### `ObjectBuilder.set(_:_:)` — Unlabeled arguments

```swift
// Current: .set("key", value)
// Proposed: .set(key: "key", value: value)
// But: .set("key", "string") reads fluently — keep unlabeled for value?
// Decision: Keep unlabeled — the call site reads naturally:
//   .set("name", "Alice")   // key, value
```

#### `ArrayBuilder.add(_:)` — OK as-is

```swift
// Current: .add("string"), .add(42) — reads naturally
// Decision: Keep
```

#### `setIfPresent` / `addIfPresent` — Document nil ambiguity

Add a note that `nil` literals are ambiguous and callers must use `as Type?`.

**Files affected:**
- `Sources/OrderedJSON/Builder/JSONBuilder.swift` — documentation only

---

### Phase 6: Sequence API Names (Low Impact) ✅

| Current | Proposed | Rationale |
|---|---|---|
| `items()` → `keyValuePairs()` | Rename to `keyValuePairs()` | `items` is not Swift-idiomatic; `keyValuePairs` is clearer | ✅ Done
| `keys()` (if exists) | `allKeys` | Standard Swift naming | N/A — no `keys()` exists
| `entries()` (if exists) | `sortedPairs` or remove | Rarely used | N/A — no `entries()` exists

**Files affected:**
- `Sources/OrderedJSON/Operators/JSONSequence.swift`

---

### Phase 7: Documentation & Complexity Annotations (Low Impact) ✅

Add documentation for O(n) properties:

- `objectKeys` — O(n) allocates new array
- `objectValues` — O(n) copies all values
- `arrayElements` — O(n) copies all elements
- `items()` — O(n) builds tuple array
- `keys()` — O(n) allocates key array
- `entries()` — O(n) builds tuple array

**Files affected:**
- `Sources/OrderedJSON/Access/JSONAccess.swift` — added O(n) docs for `objectKeys`, `arrayValue`, `objectValue` (done)
- `Sources/OrderedJSON/Operators/JSONSequence.swift` — added O(n) docs for `keyValuePairs()` (done)

---

### Phase 8: Silent No-Op Behavior (Design Decision) ✅

**Problem:** Setting a key on an array, appending to an object, erasing from the wrong type — all silently do nothing.

**Options:**
1. Keep silent no-ops (matches nlohmann/json, defensive)
2. Change to throwing errors
3. Add throwing variants alongside silent ones

**Decision:** Keep silent no-ops for `subscript` setters and `erase`/`append`. Add throwing accessors (`at(key:)`, `at(index:)`) which is already done. Document the silent behavior explicitly.

**Files affected:** Documentation only.

---

### Phase 9: `JSONPointer` API (Low Impact) ✅

| Current | Proposed | Rationale |
|---|---|---|
| `JSONPointer(_:)` throwing init | Keep | ✅ OK — `init(_ path: String)` reads fluently |
| `JSONPointer(fragment:)` | Keep | ✅ OK — explicit label |
| `resolve(_:)` | Keep | ✅ OK — reads as noun query |
| `resolveOrThrow(_:)` | Keep | ✅ OK — explicit naming |
| `set(into:value:)` | Keep | ✅ OK — prepositional phrase |

**Files affected:** None.

---

### Phase 10: Codable API Names (Low Impact) ✅

| Current | Proposed | Rationale |
|---|---|---|
| `OrderedJSONEncoder.encode(_:)` | Keep | ✅ Standard Foundation naming |
| `OrderedJSONEncoder.encodeToString(_:)` | Keep | ✅ OK — explicit |
| `OrderedJSONDecoder.decode(_:from:)` | Keep | ✅ Standard Foundation naming |

**Files affected:** None.

---

### Phase 11: SAX Protocol Naming (Medium Impact) ✅

| Current | Proposed | Rationale |
|---|---|---|
| `JSONSAXEventHandler` protocol methods | Keep | ✅ OK — `null()`, `boolean(_:)`, `string(_:)` etc. are standard SAX naming |

**Files affected:** None.

---

### Phase 12: Remove `maxCount` Property (Low Impact) ✅

`maxCount` returns `Int.max` — this is a C++-ism that is meaningless in Swift (Swift arrays don't have a fixed max). Remove it.

**Files affected:**
- `Sources/OrderedJSON/Access/JSONAccess.swift`

---

## Summary of Changes

| Phase | Breaking? | Files Touched | Effort |
|---|---|---|---|
| 1: Remove C++ names | Yes | 6-8 files | Medium |
| 2: Mutating pairs | No (additive) | 2 files | Small |
| 3: Argument labels | Yes | 2 files | Medium |
| 4: Value extraction | Yes | 1 file | Small |
| 5: Builder docs | No | 1 file | Small | ✅
| 6: Sequence naming | Yes | 1 file | Small |
| 7: Complexity docs | No | 2 files | Small |
| 8: Silent no-ops | No | Docs only | Small | ✅
| 9: JSONPointer | No | 0 | None |
| 10: Codable | No | 0 | None |
| 11: SAX | No | 0 | None |
| 12: Remove maxCount | Yes | 1 file | Small | ✅

---

### Phase 13: `require*` Throwing Accessors (Final Design)

All throwing accessors use `require` prefix to distinguish from non-throwing optional properties (`stringValue`, `intValue`, etc.). `require` signals "this throws if the type doesn't match." `get<T>()` was removed — callers use individual `require*()` methods instead.

**Final signatures (all `public`):**

| Method | Return Type | Notes |
|---|---|---|
| `requireString()` | `String` | — |
| `requireBool()` | `Bool` | — |
| `requireInt64()` | `Int64` | Accepts `.float` when clean integer |
| `requireInt()` | `Int` | Bounds-checked |
| `requireInt8()` | `Int8` | Bounds-checked |
| `requireInt16()` | `Int16` | Bounds-checked |
| `requireInt32()` | `Int32` | Bounds-checked |
| `requireUInt()` | `UInt` | Bounds-checked |
| `requireUInt8()` | `UInt8` | Bounds-checked |
| `requireUInt16()` | `UInt16` | Bounds-checked |
| `requireUInt32()` | `UInt32` | Bounds-checked |
| `requireUInt64()` | `UInt64` | Bounds-checked |
| `requireDouble()` | `Double` | Accepts both `.float` and `.integer` |
| `requireFloat()` | `Float` | Lossless conversion, rejects non-exact |

**Rationale:** `require` prefix disambiguates from non-throwing `stringValue`/`intValue` properties. Removed `get<T>()` — generic dispatch adds no safety over individual methods.

---

### Phase 14: Mutating/Nonmutating Pairs — Complete Coverage (Medium Impact)

| Current | Proposed | Rationale |
|---|---|---|
| `update(with:mergesNested:)` mutating | Add `updated(with:mergesNested:)` nonmutating | Consistent pair pattern — `clear`/`cleared`, `sort`/`sorted` |
| `mergePatch(_:)` nonmutating | Add `mergingPatch(_:)` nonmutating variant name | Currently no mutating variant; add `mergePatch(_:)` mutating |
| `patch(_:)` nonmutating + `patching(_:)` mutating | Swap to `applying(_:)` nonmutating + `patch(_:)` mutating | Current convention is **reversed**: Swift convention is base-name = mutating, -ing suffix = nonmutating. `patch(_:)` should be mutating, `applying(_:)` should be nonmutating |

**Files affected:**
- `Sources/OrderedJSON/Modifiers/JSONClear.swift` — add `updated(with:mergesNested:)`
- `Sources/OrderedJSON/Patch/JSONPatch.swift` — swap `patch`/`patching` convention
- `Sources/OrderedJSON/Patch/JSONMergePatch.swift` — add mutating `mergePatch(_:)`
- `Tests/OrderedJSONTests/Patch/JSONPatchTests.swift` — update test calls

---

### Phase 15: `erase` → `remove` (Low Impact, Breaking)

| Current | Proposed | Rationale |
|---|---|---|
| `mutating func erase(key: String)` | `mutating func remove(key: String)` | C++ naming; Swift uses `remove` for element/key removal |
| `mutating func erase(index: Int)` | `mutating func remove(at index: Int)` | C++ naming; Swift uses `remove(at:)` |

**Files affected:**
- `Sources/OrderedJSON/Modifiers/JSONClear.swift` — rename `erase` methods
- `Tests/OrderedJSONTests/Modifiers/JSONModifierTests.swift` — update test calls

---

### Phase 16: Overload Ambiguity Resolution for `contains` (High Impact)

**Problem:** `contains("foo")` on a JSON value hits the `String` overload (key lookup) instead of array element containment. Callers must use `.string("foo")` for element checks, which violates clarity at point of use.

| Current | Proposed | Rationale |
|---|---|---|
| `contains(key key: String)` | Keep as `contains(key key: String)` | Label is clear for object key lookup |
| `contains(element element: JSON)` | Keep as `contains(element element: JSON)` | Label is clear for array element containment |
| `contains(_: String)` (implicit String) | **Remove** or **deprecate** | Ambiguous — callers must use `contains(key: "foo")` for keys |
| **New:** `containsKey(_ key: String)` | Add `containsKey(_ key: String) -> Bool` | Unambiguous key lookup — reads `containsKey("foo")` |

**Decision:** Remove the unlabeled `contains(_: String)` overload. Add `containsKey(_:)` as the unambiguous key-lookup API. Keep `contains(key:)` and `contains(element:)` with labels for explicit usage.

**Files affected:**
- `Sources/OrderedJSON/Access/JSONLookup.swift` — add `containsKey`, remove unlabeled overload
- `Tests/OrderedJSONTests/Access/JSONAccessTests.swift` — update test calls

---

### Phase 17: `count(key:)` → `containsKey` (Low Impact, Breaking)

**Problem:** `count(key:)` returns `Int` (0 or 1) but semantically is a `Bool` query. Callers use it to check key existence, not to count occurrences.

| Current | Proposed | Rationale |
|---|---|---|
| `func count(key: String) -> Int` | Remove — callers use `containsKey(_:)` instead | `containsKey` is the idiomatic Bool query; `count` returning 0/1 Int is misleading |

**Files affected:**
- `Sources/OrderedJSON/Access/JSONLookup.swift` — remove `count(key:)`
- `Tests/OrderedJSONTests/Access/JSONAccessTests.swift` — update test calls

---

### Phase 18: `saxParse` → `parse` SAX API (Low Impact, Breaking)

| Current | Proposed | Rationale |
|---|---|---|
| `JSON.saxParse(_:handler:)` | `JSON.parse(_:handler:)` | "sax" prefix is redundant — the method is in the SAX file and the handler type is `JSONSAXEventHandler` |
| `JSON.accept(_:)` | Keep | `accept` is well-named for validation-only parsing |

**Files affected:**
- `Sources/OrderedJSON/SAX/JSONSAX.swift` — rename `saxParse` to `parse`
- `Tests/OrderedJSONTests/SAX/JSONSAXTests.swift` — update test calls

---

### Phase 19: `dump` Magic Number Removal (Low Impact)

**Problem:** `dump(indent: -1)` uses `-1` as a magic number for compact output. This violates clarity at point of use.

| Current | Proposed | Rationale |
|---|---|---|
| `dump(indent: Int = -1)` | `dump(indent: Int? = nil)` | `nil` means compact, `Int` means pretty-print with that indent width. No magic numbers. |
| Internal `if indent < 0` check | Internal `if let indent = indent` check | Matches Swift optional convention |

**Files affected:**
- `Sources/OrderedJSON/Parsing/JSONSerializer.swift` — change `indent` parameter type
- `Sources/OrderedJSON/Builder/JSONBuilder.swift` — update `buildString(indent:)` call sites
- `Sources/OrderedJSON/Codable/OrderedJSONEncoder.swift` — update `encodeToString` call
- `Tests/OrderedJSONTests/Parsing/JSONSerializerTests.swift` — update test calls

---

### Phase 20: `JSONIterator` Visibility (Low Impact)

| Current | Proposed | Rationale |
|---|---|---|
| `public struct JSONIterator` | `package struct JSONIterator` (or internal) | Callers only need `Sequence` conformance; the iterator type is an implementation detail |

**Files affected:**
- `Sources/OrderedJSON/Operators/JSONSequence.swift` — change access level

---

### Phase 21: `encodeToString` → `encodeAsString` (Low Impact, Breaking)

| Current | Proposed | Rationale |
|---|---|---|
| `OrderedJSONEncoder.encodeToString(_:)` | `OrderedJSONEncoder.encodeAsString(_:)` | "ToString" is not Swift naming; `encodeAsString` follows `encodeAsProperty` pattern |
| `encode(_:) -> JSON` | Keep | Standard Foundation naming ✅ |

**Files affected:**
- `Sources/OrderedJSON/Codable/OrderedJSONEncoder.swift` — rename method
- `Tests/OrderedJSONTests/Codable/OrderedJSONCodableTests.swift` — update test calls

---

### Phase 22: Schema API Naming (Medium Impact, Breaking)

| Current | Proposed | Rationale |
|---|---|---|
| `validation(of document: JSON) -> VerboseResult` | `validating(_ document: JSON) -> VerboseResult` | Nonmutating pair for `validate(_:)`. `of` label is non-standard; use `_` for clarity |
| `throwIfInvalid() throws` | `throwOnError() throws` | `throwIf` is not idiomatic Swift; `throwOnError` reads as "throw on error" |
| `isValid(_:) -> Bool` | Keep | ✅ OK — standard Swift query naming |

**Files affected:**
- `Sources/OrderedJSON/Schema/JSONSchema.swift` — rename `validation(of:)` → `validating(_:)`
- `Sources/OrderedJSON/Schema/JSONSchemaOutput.swift` — rename `throwIfInvalid()` → `throwOnError()`
- `Tests/OrderedJSONTests/Schema/JSONSchemaTests.swift` — update test calls

---

### Phase 23: `JSONWithExtras` → `JSONWithUnknownKeys` (Low Impact, Breaking)

| Current | Proposed | Rationale |
|---|---|---|
| `JSONWithExtras<T>` | `JSONWithUnknownKeys<T>` | "Extras" is ambiguous (could mean additional data, not just unknown keys). "UnknownKeys" is precise |
| `extras` property | `unknownKeys` property | Matches renamed type |
| `JSONWithExtras` file | Rename to `JSONWithUnknownKeys.swift` | File name matches type name |

**Files affected:**
- `Sources/OrderedJSON/Codable/JSONWithExtras.swift` — rename type and property
- `Sources/OrderedJSON/Codable/JSONWithExtras.swift` → rename file
- `Tests/OrderedJSONTests/Codable/OrderedJSONCodableTests.swift` — update test calls

---

### Phase 24: `JSONPointer.set(into:value:)` Label (Low Impact)

| Current | Proposed | Rationale |
|---|---|---|
| `func set(into json: inout JSON, value: JSON)` | `func set(value: JSON, into json: inout JSON)` | Prepositional phrase should describe the value first; `set(value:into:)` reads as "set value into json" |

**Files affected:**
- `Sources/OrderedJSON/Flatten/JSONPointer.swift` — swap parameter labels
- `Tests/OrderedJSONTests/Flatten/JSONPointerTests.swift` — update test calls

---

### Phase 25: `UnicodeScalarHex` Deduplication (Low Impact)

**Problem:** `private enum UnicodeScalarHex` is defined identically in both `JSONParser.swift` and `JSONSAX.swift`. This is code duplication.

| Current | Proposed | Rationale |
|---|---|---|
| Two identical `private enum UnicodeScalarHex` in `JSONParser.swift` and `JSONSAX.swift` | Extract to shared `package enum UnicodeScalarHex` in a new file `Parsing/UnicodeScalarHex.swift` | DRY — single definition shared by both parsers |

**Files affected:**
- Create `Sources/OrderedJSON/Parsing/UnicodeScalarHex.swift` — shared definition
- `Sources/OrderedJSON/Parsing/JSONParser.swift` — remove duplicate, use shared
- `Sources/OrderedJSON/SAX/JSONSAX.swift` — remove duplicate, use shared

---

### Phase 26: Builder API Label Documentation (Low Impact)

| Current | Proposed | Rationale |
|---|---|---|
| `ObjectBuilder.set(_ key, _ value)` (unlabeled) | Keep — document convention | Call site `.set("key", "value")` reads fluently but key/value roles are implicit. Document that first param is key, second is value |
| `ArrayBuilder.add(_ value)` (unlabeled) | Keep — document convention | Call site `.add("value")` reads naturally |

**Files affected:**
- `Sources/OrderedJSON/Builder/JSONBuilder.swift` — documentation only

---

### Phase 27: `contains(key:)` vs `contains(element:)` Documentation (Low Impact)

**Problem:** The `contains` overload ambiguity is resolved in Phase 16, but the `containsKey` addition needs documentation about when to use each variant.

**Files affected:**
- `Sources/OrderedJSON/Access/JSONLookup.swift` — add documentation clarifying `contains(key:)`, `contains(element:)`, and `containsKey(_:)`

---

## Summary of Changes (Complete)

| Phase | Breaking? | Files Touched | Effort |
|---|---|---|---|
| 1: Remove C++ names | Yes | 6-8 files | Medium |
| 2: Mutating pairs | No (additive) | 2 files | Small |
| 3: Argument labels | Yes | 2 files | Medium |
| 4: Value extraction | Yes | 1 file | Small |
| 5: Builder docs | No | 1 file | Small | ✅ |
| 6: Sequence naming | Yes | 1 file | Small |
| 7: Complexity docs | No | 2 files | Small |
| 8: Silent no-ops | No | Docs only | Small | ✅ |
| 9: JSONPointer | No | 0 | None |
| 10: Codable | No | 0 | None |
| 11: SAX | No | 0 | None |
| 12: Remove maxCount | Yes | 1 file | Small | ✅ |
| 13: require* → *Value | Yes | 3-4 files | Medium |
| 14: Mutating pairs complete | No (additive) | 3 files | Medium |
| 15: erase → remove | Yes | 2 files | Small |
| 16: contains ambiguity | Yes | 2 files | Medium |
| 17: count(key:) removal | Yes | 2 files | Small |
| 18: saxParse rename | Yes | 2 files | Small |
| 19: dump magic number | Yes | 3-4 files | Small |
| 20: JSONIterator visibility | No | 1 file | Small |
| 21: encodeToString rename | Yes | 2 files | Small |
| 22: Schema API naming | Yes | 3 files | Medium |
| 23: JSONWithExtras rename | Yes | 2 files | Small |
| 24: JSONPointer labels | Yes | 2 files | Small |
| 25: UnicodeScalarHex dedup | No | 3 files | Small |
| 26: Builder docs | No | 1 file | Small |
| 27: contains docs | No | 1 file | Small |

## Implementation Order (Updated)

1. Phase 3 (argument labels) — highest clarity impact, changes call sites
2. Phase 1 (C++ names) — removes confusion ✅
3. Phase 4 (floatValue → doubleValue) — prevents misuse ✅
4. Phase 16 (contains ambiguity) — prevents subtle bugs ✅
5. Phase 13 (require* → *Value) — largest naming cleanup
6. Phase 14 (mutating pairs complete) — consistent convention
7. Phase 15 (erase → remove) — C++-ism removal
8. Phase 18 (saxParse rename) — redundant prefix
9. Phase 19 (dump magic number) — clarity improvement
10. Phase 21 (encodeToString rename) — Swift naming
11. Phase 22 (Schema API naming) — clarity
12. Phase 23 (JSONWithExtras rename) — naming clarity
13. Phase 24 (JSONPointer labels) — label convention
14. Phase 17 (count(key:) removal) — depends on containsKey from Phase 16
15. Phase 2 (mutating pairs) — additive, safe ✅
16. Phase 6 (sequence naming) ✅
17. Phase 7 (documentation) ✅
18. Phase 20 (JSONIterator visibility) — safe
19. Phase 25 (UnicodeScalarHex dedup) — safe
20. Phase 26, 27 (docs) — safe
21. Phase 5, 8, 9, 10, 11 (low-impact docs) ✅
22. Phase 12 (maxCount removal) ✅
