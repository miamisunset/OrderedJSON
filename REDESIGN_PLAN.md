# OrderedJSON — nlohmann/json Swift Translation Plan

## Goal
Transform `OrderedJSON` from a minimal enum-based JSON library into an idiomatic Swift translation of **nlohmann/json** (`JSON for Modern C++`), maintaining key order preservation as the core differentiator.

## Current State
- `JSONValue` enum with 6 cases (`.object`, `.array`, `.string`, `.number`, `.boolean`, `.null`)
- `JSONNumber` enum (`.integer(Int64)`, `.float(Double)`)
- Uses `OrderedDictionary<String, JSON>` directly (no typealias)
- Standalone `parse()`, `dump()`, `flatten()`
- No subscript, no type checks, no modifiers, no JSON Pointer, no binary formats

## Target State
- `JSON` struct wrapping the enum, exposing a rich method-based API mirroring `nlohmann::basic_json`
- All existing functionality preserved + vastly expanded

---

## Architecture

### Core Type: `JSON` (replaces `JSONValue`)

```swift
public struct JSON: Hashable, Sendable {
  internal enum Storage: Hashable, Sendable {
    case object(OrderedDictionary<String, JSON>)
    case array([JSON])
    case string(String)
    case number(JSONNumber)
    case boolean(Bool)
    case null
  }
  internal var storage: Storage
}
```

**Rationale**: A struct wrapper lets us add methods (subscript, type checks, etc.) without polluting enum cases. Internally we still use the enum for storage. Externally, `JSON` feels like `nlohmann::json` — a value type you construct, access, and mutate.

### Supporting Types (unchanged)
- `JSONNumber` — stays as `.integer(Int64)` / `.float(Double)`
- No `OrderedJSONObject` typealias — use `OrderedDictionary<String, JSON>` directly

---

## API Translation Table

nlohmann/json method      | Swift translation               | Notes
--------------------------|----------------------------------|-------
`operator[]` (key/index)  | `subscript(key:)` / `subscript(index:)` | Returns `JSON?` for safe access; sets value on mutation
`at(key)` / `at(size_t)`  | `at(_ key:)` / `at(_ index:)`   | Throws on missing key/index
`value(key, default)`     | `value(_ key:default:)`         | Returns default if key missing
`is_null()`               | `isNull` (property)             | Computed var
`is_boolean()`            | `isBoolean`                     |
`is_number()`             | `isNumber`                      |
`is_number_integer()`     | `isInteger`                     |
`is_number_float()`       | `isFloat`                       |
`is_string()`             | `isString`                      |
`is_object()`             | `isObject`                      |
`is_array()`              | `isArray`                       |
`is_primitive()`          | `isPrimitive`                   |
`is_structured()`         | `isStructured`                  |
`type()`                  | `type` (property → `JSONType` enum) | `.null`, `.boolean`, `.number`, `.string`, `.object`, `.array`
`type_name()`             | `typeName` (→ `String`)         |
`dump(indent, ...)`       | `dump(indent:, indentChar:, ensureAscii:, errorHandler:)` | Default compact (-1)
`parse(input)`            | `JSON.parse(_:)` (static)       | Current implementation stays
`sax_parse(input, handler)`| `JSON.saxParse(_:handler:)` (static) | SAX callback protocol
`accept(input)`           | `JSON.accept(_:)` (static)      | Returns `Bool`, no throw
`flatten()`               | `flatten()`                      | Returns `JSON` object with JSON Pointer keys (`/a/b/c`)
`unflatten()`             | `unflatten()`                    | Reverse of flatten
`patch(patch)`            | `patch(_:)`                     | Applies JSON Patch
`patch_inplace(patch)`    | `patchInPlace(_:)`              | In-place mutation
`diff(j1, j2)`            | `JSON.diff(_:_:)` (static)      | Creates JSON Patch from two values
`merge_patch(patch)`      | `mergePatch(_:)`                | Applies JSON Merge Patch
`contains(key)`           | `contains(_ key:)`              | Key existence in object
`count(key)`              | `count(_ key:)`                 | 0 or 1 (object keys are unique)
`find(key)`               | `find(_ key:)`                  | Returns `JSON?` or `nil`
`empty()`                 | `isEmpty` (property)            |
`size()`                  | `count` (property)              |
`max_size()`              | `maxCount` (property)           | `Int.max` for unbounded
`clear()`                 | `clear()`                       | Mutates in-place
`erase(key)` / `erase(index)` | `erase(_ key:)` / `erase(_ index:)` | Remove key or index
`push_back(value)`        | `append(_ value:)`              | Appends to array
`operator+=`              | `append(_:)` or `+=` operator   |
`emplace_back(value)`     | `emplace(_ value:)`             | For arrays
`emplace(key, value)`     | `emplace(key:default:)`         | Insert if key absent
`insert(value, index)`    | `insert(_ value:at:)`           | Insert at position in array
`update(other)`           | `update(with:)`                 | Merge object keys
`swap(other)`             | `swap(&other)`                  | Mutating method
`front()` / `back()`      | `first` / `last` (properties)   |
`begin()` / `end()`       | `makeIterator()`                | Swift `Sequence` conformance
`items()`                 | `items()`                       | Key-value pairs for objects
`from_cbor()` / `to_cbor()` | `JSON.fromCBOR(_:)` / `toCBOR()` | Binary format support
`from_msgpack()` / `to_msgpack()` | `JSON.fromMsgPack(_:)` / `toMsgPack()`
`from_ubjson()` / `to_ubjson()` | `JSON.fromUBJSON(_:)` / `toUBJSON()`
`from_bson()` / `to_bson()` | `JSON.fromBSON(_:)` / `toBSON()`
`from_bjdata()` / `to_bjdata()` | `JSON.fromBJData(_:)` / `toBJData()`

### Factory Static Methods
nlohmann method | Swift translation
----------------|------------------
`json::object()`  | `JSON.object(_:)` — creates object from dictionary
`json::array()`   | `JSON.array(_:)` — creates array from elements
`json::binary()`  | `JSON.binary(_:)` — creates binary value

### Convenience Initializers
```swift
extension JSON: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral,
                ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
                ExpressibleByStringLiteral, ExpressibleByArrayLiteral,
                ExpressibleByDictionaryLiteral { ... }
```

### JSON Pointer
- `flatten()` produces keys starting with `/` (JSON Pointer format)
- `unflatten()` reconstructs nested structure from flattened object
- Separate `JSONPointer` type for pointer operations

### SAX Interface
```swift
public protocol JSONSAXEventHandler: AnyObject {
  func null() -> Bool
  func boolean(_ value: Bool) -> Bool
  func integer(_ value: Int64) -> Bool
  func float(_ value: Double, string: String) -> Bool
  func string(_ value: String) -> Bool
  func startObject() -> Bool
  func key(_ value: String) -> Bool
  func endObject() -> Bool
  func startArray() -> Bool
  func endArray() -> Bool
  func parseError(_ error: JSONParseError, data: Data) -> Bool
}
```

### Error Types
- `JSONError` — general error (existing)
- `JSONParseError` — parsing errors (existing)
- `JSONTypeError` — wrong type for operation (new)
- `JSONOutOfRangeError` — key/index out of range (new)

---

## Flatten Change
**Current**: dot-notation keys (`"a.b.c"`)
**New**: JSON Pointer keys (`"/a/b/c"`) — matching nlohmann/json

This affects `flatten()` and `unflatten()`. The old dot-notation can be kept as a separate `flattenDotted()` for backward compatibility if desired.

---

## Binary Formats (Future Phases)
Support CBOR, MessagePack, UBJSON, BSON, BJData as static `from*` / instance `to*` methods. These can be implemented incrementally.

---

## Implementation Phases

### Phase 1 — Core Struct + Type Checks + Subscript
1. Replace `JSONValue` enum with `JSON` struct wrapping `Storage` enum
2. Add computed properties: `isNull`, `isBoolean`, `isNumber`, `isInteger`, `isFloat`, `isString`, `isObject`, `isArray`, `isPrimitive`, `isStructured`, `type`, `typeName`
3. Add subscript `[key: String]` and `[index: Int]` (get/set)
4. Add `at(_ key:)` / `at(_ index:)` throwing variants
5. Add `value(_ key:default:)`
6. Add `count`, `isEmpty`, `maxCount` properties
7. Add `contains(_ key:)`, `count(_ key:)`, `find(_ key:)`
8. Add `clear()`, `erase(_ key:)`, `erase(_ index:)`, `append(_ value:)`, `insert(_ value:at:)`, `emplace(_ value:)`, `emplace(key:default:)`, `update(with:)`, `swap(&:)`
9. Add `first`, `last` properties
10. Add `flatten()`, `unflatten()` (JSON Pointer format)
11. Add `dump(...)` (pretty-printing)
12. Keep existing `parse()`, `dump()` — `dump(-1)` produces compact output

### Phase 2 — Comparison Operators + Sequence Conformance
13. Add `==`, `!=`, `<`, `>`, `<=`, `>=` operators
14. Add `Sequence` conformance for iteration
15. Add `items()` for key-value pairs

### Phase 3 — JSON Patch + Merge Patch
16. Add `patch(_:)`, `patchInPlace(_:)`, `diff(_:_:)`, `mergePatch(_:)`

### Phase 4 — SAX Parsing
17. Add `JSONSAXEventHandler` protocol
18. Add `saxParse(_:handler:)`

### Phase 5 — Binary Formats
19. Add CBOR, MessagePack, UBJSON, BSON, BJData support

### Phase 6 — Comprehensive User Documentation
20. Rewrite `README.md` with current `JSON` struct API, organized by feature area with runnable examples

---

## Backward Compatibility
- `JSONValue` can become `typealias JSONValue = JSON` or remain as an internal alias
- No `OrderedJSONObject` typealias — `OrderedDictionary<String, JSON>` used directly
- `flatten()` currently returns `[(key: String, value: JSONValue)]` — will change to return `JSON` object
- `dump()` → compact (`dump(-1)`) or pretty-printed output

---

## Key Design Decisions

1. **Struct over enum extension**: Adding methods to enum via extensions works, but subscript `[key:]` returning `Self?` with mutation is cleaner on a struct. The enum stays as internal storage.
2. **JSON Pointer flatten**: nlohmann/json uses `/` paths. We match this exactly.
3. **No Codable**: Already decided — `parse()` / `dump()` replace it.
4. **Mutable subscript**: `j["key"] = value` works because struct has mutating methods. `j["key"]` as a getter returns `JSON?`.
5. **Sendable**: `JSON` is a struct of `Sendable` parts — no `actor` needed.
6. **Multiple files**: Organized by concern, not monolithic — see File Layout below.

---

## File Layout

All source under `Sources/OrderedJSON/`, organized by module concern:

```
Sources/OrderedJSON/
├── Core/
│   ├── JSON.swift                  # JSON struct, Storage enum, type checks, factory methods
│   ├── JSONNumber.swift            # JSONNumber enum (integer/float)
│   ├── OrderedJSONObject.swift     # typealias for OrderedDictionary (removed — use OrderedDictionary directly)
│   └── JSONError.swift             # Error types: JSONError, JSONParseError, JSONTypeError, JSONOutOfRangeError
├── Parsing/
│   ├── JSONParser.swift            # Recursive descent parser (current parse logic)
│   └── JSONSerializer.swift        # Serialization (dump logic)
├── Access/
│   ├── JSONSubscript.swift         # subscript[key:], subscript[index:], at(_:), value(_:default:)
│   ├── JSONLookup.swift            # contains, count(_:), find
│   └── JSONAccess.swift            # first, last, isEmpty, count (capacity)
├── Modifiers/
│   ├── JSONClear.swift             # clear, erase, append, insert, emplace, update, swap
│   └── JSONTypeChecks.swift        # isNull, isBoolean, isNumber, etc.
├── Flatten/
│   ├── JSONFlatten.swift           # flatten (JSON Pointer format), unflatten
│   └── JSONPointer.swift           # JSONPointer type for pointer operations
├── Patch/
│   ├── JSONPatch.swift             # patch, patchInPlace, diff
│   └── JSONMergePatch.swift        # mergePatch
├── SAX/
│   └── JSONSAX.swift               # JSONSAXEventHandler protocol, saxParse
├── Binary/
│   ├── JSONCBOR.swift              # fromCBOR, toCBOR
│   ├── JSONMsgPack.swift           # fromMsgPack, toMsgPack
│   ├── JSONUBJSON.swift            # fromUBJSON, toUBJSON
│   ├── JSONBSON.swift              # fromBSON, toBSON
│   └── JSONBJData.swift            # fromBJData, toBJData
└── Operators/
    ├── JSONComparison.swift        # ==, !=, <, >, <=, >= operators
    └── JSONSequence.swift          # Sequence conformance, items(), iteration

Tests/OrderedJSONTests/
├── Core/
│   ├── JSONTests.swift             # Core JSON tests
│   ├── JSONNumberTests.swift       # JSONNumber tests
│   └── JSONErrorTests.swift        # Error type tests
├── Parsing/
│   ├── JSONParserTests.swift       # Parser tests
│   └── JSONSerializerTests.swift   # Serialization tests
├── Access/
│   ├── JSONSubscriptTests.swift    # Subscript/at/value tests
│   ├── JSONLookupTests.swift       # contains/count/find tests
│   └── JSONAccessTests.swift       # Capacity/access tests
├── Modifiers/
│   ├── JSONClearTests.swift        # Mutation tests
│   └── JSONTypeChecksTests.swift   # Type check tests
├── Flatten/
│   ├── JSONFlattenTests.swift      # flatten/unflatten tests
│   └── JSONPointerTests.swift      # JSON Pointer tests
├── Patch/
│   ├── JSONPatchTests.swift        # Patch tests
│   └── JSONMergePatchTests.swift   # Merge patch tests
├── SAX/
│   └── JSONSAXTests.swift          # SAX parsing tests
├── Binary/
│   └── (one file per format)
└── Operators/
    ├── JSONComparisonTests.swift
    └── JSONSequenceTests.swift

DocumentationExamplesTests.swift  # Keep existing doc examples
```

## Package.swift Changes

Add explicit source file layout:

```swift
.target(
  name: "OrderedJSON",
  dependencies: [
    .product("OrderedCollections", package: "swift-collections")
  ],
  path: "Sources/OrderedJSON",
  sources: [
    "Core/JSON.swift",
    "Core/JSONNumber.swift",
    // "Core/OrderedJSONObject.swift",  // removed — typealias deleted
    "Core/JSONError.swift",
    "Parsing/JSONParser.swift",
    "Parsing/JSONSerializer.swift",
    "Access/JSONSubscript.swift",
    "Access/JSONLookup.swift",
    "Access/JSONAccess.swift",
    "Modifiers/JSONClear.swift",
    "Modifiers/JSONTypeChecks.swift",
    "Flatten/JSONFlatten.swift",
    "Flatten/JSONPointer.swift",
    "Patch/JSONPatch.swift",
    "Patch/JSONMergePatch.swift",
    "SAX/JSONSAX.swift",
    "Binary/JSONCBOR.swift",
    "Binary/JSONMsgPack.swift",
    "Binary/JSONUBJSON.swift",
    "Binary/JSONBSON.swift",
    "Binary/JSONBJData.swift",
    "Operators/JSONComparison.swift",
    "Operators/JSONSequence.swift",
  ]
)
```
