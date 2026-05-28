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

## Implementation Order

1. Phase 3 (argument labels) — highest clarity impact, changes call sites
2. Phase 1 (C++ names) — removes confusion ✅
3. Phase 4 (floatValue → doubleValue) — prevents misuse ✅
4. Phase 2 (mutating pairs) — adds consistency ✅
5. Phase 6 (sequence naming) ✅
6. Phase 7 (documentation) ✅
7. Phase 5, 8, 9, 10, 11 (low-impact docs) ✅
8. Phase 12 (maxCount removal) ✅
